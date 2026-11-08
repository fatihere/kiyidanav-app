import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'cevrimdisi.dart';
import 'locate.dart';
import 'mera.dart';
import 'notices.dart';
import 'sea.dart';
import 'sea_card.dart';
import 'solunar.dart';
import 'theme.dart';
import 'weather_icon.dart';

/// 1.15.0 — Av günüm ve geçmiş 7 gün.
/// * Geçmiş hava: Open-Meteo `past_days=7` (hava) + deniz modeli `past_days=7` (dalga, su sıcaklığı).
/// * Av günüm: kullanıcı balık tuttuğu günü kaydeder; o günün rüzgârı, rüzgâr yönü, dalgası ve ay evresi
///   önümüzdeki günlerde yeniden oluşursa telefonda bildirim çıkar (arka plan denetimi, sunucuya veri gitmez).

/// Bir günün (geçmiş ya da tahmin) özet koşulları
class GunHava {
  final DateTime tarih;
  final double? ruzgar, hamle, dalga, su, yagis, tmax, tmin, basinc;
  final int? yon, kod;
  const GunHava(this.tarih,
      {this.ruzgar, this.hamle, this.dalga, this.su, this.yagis, this.tmax, this.tmin, this.basinc, this.yon, this.kod});

  /// Hamleleri de sayan etkin rüzgâr
  double? get etkinRuzgar {
    if (ruzgar == null && hamle == null) return null;
    final a = ruzgar ?? 0, b = (hamle ?? 0) * 0.7;
    return a > b ? a : b;
  }

  int get skor => FishingScore.compute(DateTime(tarih.year, tarih.month, tarih.day, 12),
      windKmh: etkinRuzgar, waveM: dalga, rainMm: yagis);

  double get ay => Moon.illumination(DateTime(tarih.year, tarih.month, tarih.day, 21));

  String get yonAdi {
    final d = yon;
    if (d == null) return '';
    const names = ['Yıldız', 'Poyraz', 'Gündoğusu', 'Keşişleme', 'Kıble', 'Lodos', 'Günbatısı', 'Karayel'];
    return names[((d % 360) / 45).round() % 8];
  }
}

class GecmisHava {
  static double? _n(dynamic v) => v is num ? v.toDouble() : null;
  static dynamic _at(dynamic l, int i) => (l is List && i < l.length) ? l[i] : null;

  /// Seçili meranın son 7 günü (dün → 7 gün önce, en yeni başta)
  static Future<List<GunHava>> son7(Spot s) async {
    final wx = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${s.lat}',
      'longitude': '${s.lon}',
      'daily': 'wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,precipitation_sum,'
          'temperature_2m_max,temperature_2m_min,weather_code',
      'hourly': 'pressure_msl',
      'past_days': '7',
      'forecast_days': '1',
      'wind_speed_unit': 'kmh',
      'timezone': 'Europe/Istanbul',
    });
    final mr = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
      'latitude': '${s.custom ? s.lat : (s.seaLat ?? s.lat)}',
      'longitude': '${s.custom ? s.lon : (s.seaLon ?? s.lon)}',
      'daily': 'wave_height_max',
      'hourly': 'sea_surface_temperature',
      'past_days': '7',
      'forecast_days': '1',
      'timezone': 'Europe/Istanbul',
    });
    final r = await Future.wait([Cevrimdisi.get(wx), Cevrimdisi.get(mr).catchError((_) => http.Response('{}', 200))]);
    final w = jsonDecode(r[0].body) as Map;
    Map m = const {};
    try {
      final x = jsonDecode(r[1].body);
      if (x is Map) m = x;
    } catch (_) {}
    final d = (w['daily'] ?? {}) as Map;
    final md = (m['daily'] ?? {}) as Map;
    final gunler = (d['time'] as List?) ?? const [];
    final mGunler = ((md['time'] as List?) ?? const []).map((e) => '$e').toList();
    // saatlik → günlük ortalama
    Map<String, double> ortalama(Map h, String alan) {
      final t = (h['time'] as List?) ?? const [];
      final v = (h[alan] as List?) ?? const [];
      final top = <String, List<double>>{};
      for (var i = 0; i < t.length && i < v.length; i++) {
        final x = _n(v[i]);
        if (x != null) top.putIfAbsent('${t[i]}'.substring(0, 10), () => []).add(x);
      }
      return top.map((k, l) => MapEntry(k, l.reduce((a, b) => a + b) / l.length));
    }

    final basinc = ortalama((w['hourly'] ?? {}) as Map, 'pressure_msl');
    final su = ortalama((m['hourly'] ?? {}) as Map, 'sea_surface_temperature');
    final bugun = DateTime.now();
    final out = <GunHava>[];
    for (var i = 0; i < gunler.length; i++) {
      final g = DateTime.tryParse('${gunler[i]}');
      if (g == null || !g.isBefore(DateTime(bugun.year, bugun.month, bugun.day))) continue;
      final k = '${gunler[i]}';
      final mi = mGunler.indexOf(k);
      out.add(GunHava(g,
          ruzgar: _n(_at(d['wind_speed_10m_max'], i)),
          hamle: _n(_at(d['wind_gusts_10m_max'], i)),
          yon: _n(_at(d['wind_direction_10m_dominant'], i))?.round(),
          yagis: _n(_at(d['precipitation_sum'], i)),
          tmax: _n(_at(d['temperature_2m_max'], i)),
          tmin: _n(_at(d['temperature_2m_min'], i)),
          kod: _n(_at(d['weather_code'], i))?.round(),
          dalga: s.strait || mi < 0 ? null : _n(_at(md['wave_height_max'], mi)),
          su: su[k],
          basinc: basinc[k]));
    }
    return out.reversed.toList();
  }

  /// Tahmindeki bir gün (av günü eşleşmesi için)
  static GunHava tahmin(SpotForecast f, int i) {
    final d = f.days[i];
    return GunHava(d.date,
        ruzgar: d.windMax, hamle: d.gustMax, dalga: f.spot.strait ? null : d.waveMax, yagis: d.rainSum, tmax: d.tempMax,
        tmin: d.tempMin, yon: d.windDir, kod: d.weatherCode, su: i == 0 ? f.now.seaC : null);
  }
}

// =================================================================== av günüm
class AvGunu {
  final String id;
  final DateTime tarih;
  final String spot; // spotToKey
  final String spotAd;
  final double? ruzgar, dalga, su;
  final int? yon;
  final double ay;
  final String not;
  const AvGunu(
      {required this.id,
      required this.tarih,
      required this.spot,
      required this.spotAd,
      this.ruzgar,
      this.dalga,
      this.su,
      this.yon,
      required this.ay,
      this.not = ''});

  factory AvGunu.gunden(Spot s, GunHava g, {String not = ''}) => AvGunu(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      tarih: DateTime(g.tarih.year, g.tarih.month, g.tarih.day),
      spot: spotToKey(s),
      spotAd: s.name,
      ruzgar: g.etkinRuzgar,
      dalga: g.dalga,
      su: g.su,
      yon: g.yon,
      ay: g.ay,
      not: not);

  static double? _n(dynamic v) => v is num ? v.toDouble() : null;

  factory AvGunu.fromJson(Map j) => AvGunu(
      id: '${j['id']}',
      tarih: DateTime.tryParse('${j['tarih']}') ?? DateTime(2000),
      spot: '${j['spot']}',
      spotAd: '${j['spotAd'] ?? ''}',
      ruzgar: _n(j['ruzgar']),
      dalga: _n(j['dalga']),
      su: _n(j['su']),
      yon: _n(j['yon'])?.round(),
      ay: _n(j['ay']) ?? 0,
      not: '${j['not'] ?? ''}');

  Map<String, dynamic> toJson() => {
        'id': id,
        'tarih': tarih.toIso8601String(),
        'spot': spot,
        'spotAd': spotAd,
        'ruzgar': ruzgar,
        'dalga': dalga,
        'su': su,
        'yon': yon,
        'ay': ay,
        'not': not,
      };

  String get ozet => [
        if (ruzgar != null) 'rüzgâr ${ruzgar!.round()} km/s${yon != null ? ' ${GunHava(tarih, yon: yon).yonAdi}' : ''}',
        if (dalga != null) 'dalga ${dalga!.toStringAsFixed(1)} m',
        if (su != null) 'su ${su!.round()}°',
        'ay %${(ay * 100).round()}',
      ].join(' · ');

  /// Başka bir günün koşulları bu av gününe benziyor mu? (rüzgâr ±6 km/s, yön ±45°, dalga ±0,3 m, ay ±%25)
  bool benzer(GunHava g) {
    final r = g.etkinRuzgar;
    if (ruzgar == null || r == null || (ruzgar! - r).abs() > 6) return false;
    if (yon != null && g.yon != null) {
      final fark = ((yon! - g.yon!).abs() % 360);
      if ((fark > 180 ? 360 - fark : fark) > 45) return false;
    }
    if (dalga != null && g.dalga != null && (dalga! - g.dalga!).abs() > 0.3) return false;
    if ((ay - g.ay).abs() > 0.25) return false;
    return true;
  }
}

String avTarih(DateTime t) {
  const aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  const gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  return '${t.day} ${aylar[t.month]} · ${gunler[t.weekday - 1]}';
}

class AvGunleri {
  static const _key = 'av_gunleri_v1', _bildirildi = 'av_gunleri_bildirildi_v1';
  static final liste = ValueNotifier<List<AvGunu>>(const []);

  static Future<void> yukle() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(_key);
      final j = s == null ? const [] : jsonDecode(s);
      liste.value = (j is List ? j : const []).whereType<Map>().map(AvGunu.fromJson).toList();
    } catch (_) {}
  }

  static Future<void> _kaydet() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(liste.value.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> ekle(AvGunu a) async {
    final l = liste.value.where((e) => !(e.spot == a.spot && e.tarih == a.tarih)).toList();
    liste.value = [a, ...l].take(20).toList();
    await _kaydet();
  }

  static Future<void> sil(String id) async {
    liste.value = liste.value.where((e) => e.id != id).toList();
    await _kaydet();
  }

  /// Arka planda: kayıtlı av günlerinin koşulları bugün/yarın/öbür gün yeniden oluşuyorsa günde bir kez bildirim
  static Future<void> arkaPlanKontrol() async {
    try {
      await yukle();
      if (liste.value.isEmpty) return;
      final p = await SharedPreferences.getInstance();
      final bildirildi = Map<String, dynamic>.from(jsonDecode(p.getString(_bildirildi) ?? '{}') as Map);
      final tahminler = <String, SpotForecast>{};
      for (final a in liste.value) {
        final f = tahminler[a.spot] ??= await SeaService.fetchWeek(spotFromKey(a.spot));
        for (var i = 0; i < 3 && i < f.days.length; i++) {
          final g = GecmisHava.tahmin(f, i);
          if (!a.benzer(g)) continue;
          final k = '${a.id}|${g.tarih.toIso8601String().substring(0, 10)}';
          if (bildirildi.containsKey(k)) break;
          bildirildi[k] = DateTime.now().toIso8601String();
          final ne = i == 0 ? 'bugün' : (i == 1 ? 'yarın' : avTarih(g.tarih).split(' · ').last);
          await Notices.yerelGoster(Notice(
            id: 'avgunu-$k',
            type: 'rapor',
            title: '🎣 Av günün geri geliyor: ${a.spotAd}',
            body: '${avTarih(a.tarih).split(' · ').first} günkü koşullar $ne yeniden oluşuyor: '
                'rüzgâr ${g.etkinRuzgar?.round() ?? '-'} km/s ${g.yonAdi}'
                '${g.dalga != null ? ', dalga ${g.dalga!.toStringAsFixed(1)} m' : ''}.',
            image: '',
            target: '',
            date: DateTime.now().toIso8601String(),
          ));
          break;
        }
      }
      final sinir = DateTime.now().subtract(const Duration(days: 10));
      bildirildi.removeWhere((_, v) => (DateTime.tryParse('$v') ?? DateTime(2000)).isBefore(sinir));
      await p.setString(_bildirildi, jsonEncode(bildirildi));
    } catch (e) {
      debugPrint('av günü arka plan: $e');
    }
  }
}

/// Mera Bilgisi'nde "Kural oluştur"un hemen altındaki kart
class AvGunuKarti extends StatefulWidget {
  final SpotForecast f;
  const AvGunuKarti({super.key, required this.f});

  @override
  State<AvGunuKarti> createState() => _AvGunuKartiState();
}

class _AvGunuKartiState extends State<AvGunuKarti> {
  @override
  void initState() {
    super.initState();
    AvGunleri.yukle();
  }

  Future<void> _bugunuKaydet() async {
    final f = widget.f;
    final g = f.days.isNotEmpty
        ? GecmisHava.tahmin(f, 0)
        : GunHava(DateTime.now(), ruzgar: f.now.windKmh, hamle: f.now.gustKmh, dalga: f.now.waveM, yon: f.now.windDir);
    await _kaydet(f.spot, GunHava(g.tarih,
        ruzgar: f.now.windKmh ?? g.ruzgar, hamle: f.now.gustKmh ?? g.hamle, dalga: f.now.strait ? null : (f.now.waveM ?? g.dalga),
        su: f.now.seaC, yon: f.now.windDir ?? g.yon, yagis: g.yagis));
  }

  Future<void> _kaydet(Spot s, GunHava g) async {
    final not = await _notSor(context);
    if (not == null) return;
    await AvGunleri.ekle(AvGunu.gunden(s, g, not: not));
    if (!mounted) return;
    final izin = await Notices.ensurePermission(context, explain: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(izin
            ? '${avTarih(g.tarih).split(' · ').first} av günün kaydedildi. Aynı koşullar oluşunca haber vereceğiz.'
            : 'Av günün kaydedildi. Haber alabilmen için bildirimleri açmalısın.')));
  }

  Future<void> _gecmistenSec() async {
    final s = widget.f.spot;
    final g = await showModalBottomSheet<GunHava>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .8,
        child: FutureBuilder<List<GunHava>>(
          future: GecmisHava.son7(s),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return snap.hasError
                  ? const Center(child: Text('Geçmiş hava alınamadı. İnternet bağlantını kontrol et.'))
                  : const Center(child: CircularProgressIndicator());
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Text('${s.name}: hangi gün avlandın?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final d in snap.data!)
                Card(
                  child: ListTile(
                    leading: Icon(WeatherLook.of(d.kod).icon, color: WeatherLook.of(d.kod).color),
                    title: Text(avTarih(d.tarih), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_gunOzet(d)),
                    trailing: const Icon(Icons.add_circle_outline, color: Tide.turuncu),
                    onTap: () => Navigator.of(ctx).pop(d),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
    if (g != null && mounted) await _kaydet(s, g);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E2D6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.event_available, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Av günüm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
              'Balık tuttuğun günü kaydet. O günün rüzgârı, rüzgâr yönü, dalgası ve ay evresi önümüzdeki günlerde '
              'yeniden oluşursa sana bildirim gönderelim.',
              style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF55544A))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                onPressed: _bugunuKaydet,
                icon: const Icon(Icons.today, size: 18),
                label: const Text('Bugün', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _gecmistenSec,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Son 7 gün'),
              ),
            ),
          ]),
          ValueListenableBuilder<List<AvGunu>>(
            valueListenable: AvGunleri.liste,
            builder: (context, l, _) => Column(children: [
              for (final a in l.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.set_meal, color: Tide.turuncu),
                  title: Text('${a.spotAd} · ${avTarih(a.tarih)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([a.ozet, if (a.not.isNotEmpty) a.not].join('\n')),
                  trailing: IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => AvGunleri.sil(a.id),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<String?> _notSor(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Av gününü kaydet'),
      content: TextField(
        controller: c,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', hintText: 'ör. 3 levrek, akşamüstü, kaşık'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Kaydet')),
      ],
    ),
  );
}

String _gunOzet(GunHava d) => [
      if (d.etkinRuzgar != null) 'Rüzgâr ${d.etkinRuzgar!.round()} km/s ${d.yonAdi}',
      if (d.dalga != null) 'dalga ${d.dalga!.toStringAsFixed(1)} m',
      if (d.su != null) 'su ${d.su!.round()}°',
      if (d.tmax != null) 'hava ${d.tmin?.round() ?? '-'}–${d.tmax!.round()}°',
      if (d.yagis != null && d.yagis! >= 0.5) 'yağış ${d.yagis!.toStringAsFixed(1)} mm',
    ].join(', ');

// =================================================================== Hesabım › son 7 gün
class GecmisRaporEkrani extends StatefulWidget {
  const GecmisRaporEkrani({super.key});

  @override
  State<GecmisRaporEkrani> createState() => _GecmisRaporEkraniState();
}

class _GecmisRaporEkraniState extends State<GecmisRaporEkrani> {
  late Spot _spot = selectedSpot.value;
  late Future<List<GunHava>> _veri = GecmisHava.son7(_spot);
  Future<MeraInfo?>? _kesit;

  @override
  void initState() {
    super.initState();
    _kesit = MeraService.of(_spot);
    selectedSpot.addListener(_degisti);
  }

  @override
  void dispose() {
    selectedSpot.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() => setState(() {
        _spot = selectedSpot.value;
        _veri = GecmisHava.son7(_spot);
        _kesit = MeraService.of(_spot);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Son 7 gün · hava ve mera')),
      body: MemberGate(
        title: 'Geçmiş raporlar üyelere özel',
        message: 'Ücretsiz üye ol; seçtiğin meranın son 7 gününe ait hava, deniz ve av verimliliği raporlarına ulaş.',
        child: RefreshIndicator(
          onRefresh: () async => _degisti(),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: const Icon(Icons.place, color: Tide.turuncu),
                title: Text('${_spot.name} · ${_spot.side.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Text('Değiştir', style: TextStyle(color: Tide.turuncu, fontWeight: FontWeight.w700)),
                onTap: () => showSpotPicker(context, listeOnly: true),
              ),
            ),
            FutureBuilder<MeraInfo?>(
              future: _kesit,
              builder: (_, s) => s.data == null || s.data!.dip.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Dip yapısı: ${s.data!.dip}', style: const TextStyle(color: Tide.misina)),
                    ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<GunHava>>(
              future: _veri,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                      padding: EdgeInsets.all(24), child: Text('Geçmiş veriler alınamadı. İnternet bağlantını kontrol et.'));
                }
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                return Column(children: [for (final d in snap.data!) _GunKarti(spot: _spot, d: d)]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _GunKarti extends StatelessWidget {
  final Spot spot;
  final GunHava d;
  const _GunKarti({required this.spot, required this.d});

  @override
  Widget build(BuildContext context) {
    final skor = d.skor;
    final w = WeatherLook.of(d.kod);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(w.icon, color: w.color),
            const SizedBox(width: 8),
            Expanded(child: Text(avTarih(d.tarih), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(20)),
              child: Text('%$skor · ${FishingScore.label(skor)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [
            if (d.etkinRuzgar != null) _bilgi(Icons.air, 'Rüzgâr', '${d.ruzgar?.round() ?? '-'} km/s ${d.yonAdi}'),
            if (d.hamle != null) _bilgi(Icons.storm, 'Hamle', '${d.hamle!.round()} km/s'),
            _bilgi(Icons.waves, 'Dalga', d.dalga == null ? (spot.strait ? '${spot.shelter} içi' : '—') : '${d.dalga!.toStringAsFixed(1)} m'),
            if (d.su != null) _bilgi(Icons.water, 'Su', '${d.su!.toStringAsFixed(1)}°'),
            if (d.tmax != null) _bilgi(Icons.thermostat, 'Hava', '${d.tmin?.round() ?? '-'}–${d.tmax!.round()}°'),
            if (d.basinc != null) _bilgi(Icons.speed, 'Basınç', '${d.basinc!.round()} hPa'),
            if (d.yagis != null) _bilgi(Icons.water_drop_outlined, 'Yağış', '${d.yagis!.toStringAsFixed(1)} mm'),
            _bilgi(Icons.dark_mode_outlined, 'Ay', '${Moon.phaseName(d.tarih)} (%${(d.ay * 100).round()})'),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Av günüm olarak kaydet'),
              onPressed: () async {
                final not = await _notSor(context);
                if (not == null) return;
                await AvGunleri.ekle(AvGunu.gunden(spot, d, not: not));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Av günün kaydedildi. Aynı koşullar oluşunca haber vereceğiz.')));
                }
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bilgi(IconData i, String b, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: Tide.misina),
        const SizedBox(width: 4),
        Text('$b: ', style: const TextStyle(fontSize: 12.5, color: Tide.misina)),
        Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]);
}

/// Hesabım'daki giriş satırı (üyelere)
void gecmisRaporAc(BuildContext context) {
  if (!appState.isMember) {
    showMemberPrompt(context, 'Son 7 günün raporları');
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GecmisRaporEkrani()));
}
