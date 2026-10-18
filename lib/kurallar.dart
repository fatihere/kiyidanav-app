import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'balik_rehberi.dart';
import 'kiyilama.dart';
import 'notices.dart';
import 'sea.dart';
import 'solunar.dart';
import 'theme.dart';

/// Kullanıcının kendi bildirim kuralı: tüm koşullar tutunca (VE) bildirim gelir.
/// Kurallar telefonda saklanır ve arka plan kontrolünde (yaklaşık 30 dakikada bir) değerlendirilir.
class Kosul {
  final String alan; // skor | ruzgar | dalga | su | hava | kiyi
  final String op; // <= | >= | =
  final String deger;
  const Kosul(this.alan, this.op, this.deger);

  Map<String, dynamic> toJson() => {'a': alan, 'o': op, 'd': deger};
  factory Kosul.fromJson(Map j) => Kosul('${j['a']}', '${j['o']}', '${j['d']}');

  static const alanlar = {
    'skor': ('Av verimliliği', '%'),
    'ruzgar': ('Rüzgâr', 'km/s'),
    'dalga': ('Dalga', 'm'),
    'su': ('Su sıcaklığı', '°C'),
    'hava': ('Hava sıcaklığı', '°C'),
    'kiyi': ('Rüzgâr–kıyı', ''),
  };
  static const kiyiSecenek = {'denizden': 'Denizden kıyıya', 'karadan': 'Kıyıdan açığa', 'paralel': 'Kıyıya paralel'};

  String get metin {
    if (alan == 'kiyi') return 'rüzgâr ${kiyiSecenek[deger]?.toLowerCase() ?? deger}';
    final a = alanlar[alan];
    return '${a?.$1.toLowerCase() ?? alan} ${op == '<=' ? '≤' : '≥'} $deger${a == null || a.$2.isEmpty ? '' : ' ${a.$2}'}';
  }
}

class Kural {
  final String id;
  final String ad;
  final List<Kosul> kosullar;
  final bool bildirim;
  const Kural(this.id, this.ad, this.kosullar, {this.bildirim = true});

  Map<String, dynamic> toJson() => {'id': id, 'ad': ad, 'k': kosullar.map((e) => e.toJson()).toList(), 'b': bildirim};
  factory Kural.fromJson(Map j) => Kural('${j['id']}', '${j['ad']}',
      ((j['k'] as List?) ?? const []).whereType<Map>().map(Kosul.fromJson).toList(),
      bildirim: j['b'] != false);

  String get metin => kosullar.map((k) => k.metin).join(' ve ');
}

/// Bir günün kuralla karşılaştırılan değerleri
class GunDegeri {
  final int skor;
  final double ruzgar, dalga;
  final double? su, hava;
  final RuzgarKiyi kiyi;
  const GunDegeri(this.skor, this.ruzgar, this.dalga, this.su, this.hava, this.kiyi);
}

class Kurallar {
  static const _key = 'kurallar_v1';
  static const _bildirildiKey = 'kurallar_bildirildi_v1';
  static final liste = ValueNotifier<List<Kural>>(const []);

  static Future<void> yukle() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(_key);
      final j = s == null ? const [] : jsonDecode(s);
      liste.value = (j is List ? j : const []).whereType<Map>().map(Kural.fromJson).toList();
    } catch (_) {}
  }

  static Future<void> _kaydet() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(liste.value.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> ekle(Kural k) async {
    liste.value = [...liste.value, k];
    await _kaydet();
  }

  static Future<void> sil(String id) async {
    liste.value = liste.value.where((k) => k.id != id).toList();
    await _kaydet();
  }

  /// [i]. günün (0 = bugün) değerleri; bugün için rapordaki skor kullanılır
  static GunDegeri gun(SpotForecast f, int i, {int? bugunSkor}) {
    final d = f.days[i];
    final skor = i == 0 && bugunSkor != null
        ? bugunSkor
        : FishingScore.compute(d.date.add(const Duration(hours: 12)), windKmh: d.effectiveWind, waveM: d.waveMax, rainMm: d.rainSum);
    final r = i == 0 ? f.now : null;
    return GunDegeri(
      skor,
      (i == 0 ? r!.effectiveWind : d.effectiveWind) ?? 0,
      (i == 0 ? r!.effectiveWave : d.waveMax) ?? 0,
      i == 0 ? r!.seaC : null,
      i == 0 ? r!.airC : d.tempMax,
      ruzgarKiyi(kiyiYonu(f.spot), (i == 0 ? r!.windDir : d.windDir)?.toDouble()),
    );
  }

  static bool tutar(Kural k, GunDegeri g) {
    if (k.kosullar.isEmpty) return false;
    for (final c in k.kosullar) {
      if (c.alan == 'kiyi') {
        if (g.kiyi.name != c.deger) return false;
        continue;
      }
      final v = switch (c.alan) {
        'skor' => g.skor.toDouble(),
        'ruzgar' => g.ruzgar,
        'dalga' => g.dalga,
        'su' => g.su,
        'hava' => g.hava,
        _ => null,
      };
      final x = double.tryParse(c.deger.replaceAll(',', '.'));
      if (v == null || x == null) return false;
      if (c.op == '<=' ? v > x : v < x) return false;
    }
    return true;
  }

  /// Arka planda: kural seçili mera için bugün ya da yarın tutuyorsa günde bir kez bildirim
  static Future<void> arkaPlanKontrol() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool('member_v1') ?? false)) return;
      await yukle();
      final aktif = liste.value.where((k) => k.bildirim).toList();
      if (aktif.isEmpty) return;
      final spot = spotFromKey(p.getString('spot_v2'));
      final f = await SeaService.fetchWeek(spot);
      final bildirildi = Map<String, dynamic>.from(jsonDecode(p.getString(_bildirildiKey) ?? '{}') as Map);
      for (final k in aktif) {
        for (var i = 0; i < 2 && i < f.days.length; i++) {
          final g = gun(f, i, bugunSkor: i == 0
              ? FishingScore.compute(DateTime.now(),
                  windKmh: f.now.effectiveWind, waveM: f.now.effectiveWave, pressureTrend: f.pressureTrend, rainMm: f.now.rainDay)
              : null);
          if (!tutar(k, g)) continue;
          final gunKey = '${k.id}|${f.days[i].date.toIso8601String().substring(0, 10)}';
          if (bildirildi.containsKey(gunKey)) break;
          bildirildi[gunKey] = DateTime.now().toIso8601String();
          await Notices.yerelGoster(Notice(
            id: 'kural-$gunKey',
            type: 'rapor-kural',
            title: '🔔 ${k.ad}',
            body: '${spot.name}: ${i == 0 ? 'bugün' : 'yarın'} koşullar tutuyor — av verimliliği %${g.skor}, '
                'rüzgâr ${g.ruzgar.round()} km/s, dalga ${g.dalga.toStringAsFixed(1)} m.',
            image: '',
            target: '',
            date: DateTime.now().toIso8601String(),
          ));
          break;
        }
      }
      // 10 günden eski kayıtları temizle
      final sinir = DateTime.now().subtract(const Duration(days: 10));
      bildirildi.removeWhere((_, v) => (DateTime.tryParse('$v') ?? DateTime(2000)).isBefore(sinir));
      await p.setString(_bildirildiKey, jsonEncode(bildirildi));
    } catch (e) {
      debugPrint('kurallar arka plan: $e');
    }
  }
}

/// "Kural oluştur" kartı — 7 günlük tahminin altında
class KuralKarti extends StatefulWidget {
  final SpotForecast f;
  final int bugunSkor;
  const KuralKarti({super.key, required this.f, required this.bugunSkor});

  @override
  State<KuralKarti> createState() => _KuralKartiState();
}

class _KuralKartiState extends State<KuralKarti> {
  final _ad = TextEditingController();
  final List<Kosul> _yeni = [const Kosul('ruzgar', '<=', '18'), const Kosul('dalga', '<=', '0.6')];
  bool _bildirim = true;
  bool _acik = false;

  @override
  void initState() {
    super.initState();
    Kurallar.yukle().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  List<int> _gunler(Kural k) => [
        for (var i = 0; i < widget.f.days.length; i++)
          if (Kurallar.tutar(k, Kurallar.gun(widget.f, i, bugunSkor: widget.bugunSkor))) i
      ];

  String _gunAdi(int i) {
    if (i == 0) return 'bugün';
    if (i == 1) return 'yarın';
    const g = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return g[widget.f.days[i].date.weekday - 1];
  }

  Future<void> _kaydet() async {
    if (_yeni.isEmpty) return;
    final k = Kural('${DateTime.now().millisecondsSinceEpoch}', _ad.text.trim().isEmpty ? 'Kuralım' : _ad.text.trim(), [..._yeni],
        bildirim: _bildirim);
    await Kurallar.ekle(k);
    _ad.clear();
    if (_bildirim && mounted) await Notices.ensurePermission(context, explain: true);
    if (!mounted) return;
    setState(() => _acik = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kural kaydedildi: ${k.ad}')));
  }

  @override
  Widget build(BuildContext context) {
    const yazi = TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35);
    const soluk = TextStyle(color: Color(0xFFBFD6D1), fontSize: 12);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Tide.derin, Tide.derinAcik]),
      ),
      child: ValueListenableBuilder<List<Kural>>(
        valueListenable: Kurallar.liste,
        builder: (context, liste, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Tide.turuncu, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Kural oluştur', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                Text('Koşullar tutunca ${widget.f.spot.name} için bildirim gelsin', style: soluk),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          if (liste.isEmpty && !_acik) const Text('Henüz kuralın yok. Örneğin "rüzgâr ≤ 18 km/s ve dalga ≤ 0,6 m".', style: soluk),
          for (final k in liste)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                  child: Builder(builder: (_) {
                    final g = _gunler(k);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.ad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(k.metin, style: soluk),
                      const SizedBox(height: 2),
                      Text(
                        g.isEmpty
                            ? '7 günde tutmuyor'
                            : '${g.contains(0) ? 'Bugün tutuyor · ' : ''}7 günde ${g.length} gün: ${g.map(_gunAdi).join(', ')}',
                        style: TextStyle(
                            color: g.contains(0) ? const Color(0xFF8BE0A4) : const Color(0xFFFFC9A8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ]);
                  }),
                ),
                IconButton(
                  tooltip: 'Kuralı sil',
                  onPressed: () => Kurallar.sil(k.id),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFBFD6D1)),
                ),
              ]),
            ),
          if (!_acik)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                onPressed: () => setState(() => _acik = true),
                icon: const Icon(Icons.add),
                label: const Text('Yeni kural'),
              ),
            )
          else ...[
            TextField(
              controller: _ad,
              style: const TextStyle(color: Colors.white),
              decoration: _dek('Kural adı (ör. Sabah levrek havası)'),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _yeni.length; i++) _kosulSatiri(i),
            Row(children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => setState(() => _yeni.add(const Kosul('skor', '>=', '60'))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Koşul ekle'),
              ),
              const Spacer(),
              const Text('Bildirim', style: yazi),
              Switch(value: _bildirim, onChanged: (v) => setState(() => _bildirim = v)),
            ]),
            Row(children: [
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFBFD6D1)),
                  onPressed: () => setState(() => _acik = false),
                  child: const Text('Vazgeç')),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                onPressed: _yeni.isEmpty ? null : _kaydet,
                child: const Text('Kuralı kaydet'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  InputDecoration _dek(String h) => InputDecoration(
        hintText: h,
        hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
        isDense: true,
        filled: true,
        fillColor: const Color(0x1FFFFFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  Widget _kosulSatiri(int i) {
    final c = _yeni[i];
    void degis(Kosul k) => setState(() => _yeni[i] = k);
    const st = TextStyle(color: Colors.white, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: DropdownButton<String>(
            value: c.alan,
            isExpanded: true,
            dropdownColor: Tide.derin,
            style: st,
            underline: const SizedBox.shrink(),
            items: [for (final e in Kosul.alanlar.entries) DropdownMenuItem(value: e.key, child: Text(e.value.$1))],
            onChanged: (v) => degis(v == 'kiyi' ? const Kosul('kiyi', '=', 'denizden') : Kosul(v!, c.alan == 'kiyi' ? '<=' : c.op, c.alan == 'kiyi' ? '10' : c.deger)),
          ),
        ),
        const SizedBox(width: 6),
        if (c.alan == 'kiyi')
          Expanded(
            flex: 6,
            child: DropdownButton<String>(
              value: c.deger,
              isExpanded: true,
              dropdownColor: Tide.derin,
              style: st,
              underline: const SizedBox.shrink(),
              items: [for (final e in Kosul.kiyiSecenek.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => degis(Kosul('kiyi', '=', v!)),
            ),
          )
        else ...[
          SizedBox(
            width: 52,
            child: DropdownButton<String>(
              value: c.op,
              isExpanded: true,
              dropdownColor: Tide.derin,
              style: st,
              underline: const SizedBox.shrink(),
              items: const [DropdownMenuItem(value: '<=', child: Text('≤')), DropdownMenuItem(value: '>=', child: Text('≥'))],
              onChanged: (v) => degis(Kosul(c.alan, v!, c.deger)),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              key: ValueKey('kosul-$i-${c.alan}'),
              initialValue: c.deger,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: st,
              decoration: _dek(Kosul.alanlar[c.alan]?.$2 ?? ''),
              onChanged: (v) => _yeni[i] = Kosul(c.alan, c.op, v.trim()),
            ),
          ),
        ],
        IconButton(
          tooltip: 'Koşulu sil',
          onPressed: () => setState(() => _yeni.removeAt(i)),
          icon: const Icon(Icons.close, color: Color(0xFFBFD6D1), size: 18),
        ),
      ]),
    );
  }
}

