import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catches.dart';
import 'config.dart';
import 'harita_secici.dart';
import 'hata.dart';
import 'locate.dart';
import 'main.dart' show Shell, shellTab;
import 'meralarim.dart';
import 'screens/catch_screens.dart' show ensureCatchToken;
import 'sea.dart';
import 'sea_card.dart';
import 'theme.dart';

/// 1.14.0 — Mera öner: üyeler tatlı su ve tuzlu su meralarını önerir; yönetici onayından sonra
/// "Topluluk meraları" olarak herkese görünür. Üye isterse "Bu mera <Ad Soyad> tarafından önerildi" yazar
/// (ad, sitedeki doğrulanmış üyelik kaydından sunucuda alınır). Sunucu: kiyidanav.com/mobil-kiyidabiri.php
enum MeraTuru {
  tuzlu('Tuzlu su', 'Deniz kıyısı: burun, mendirek, iskele, kumsal'),
  tatli('Tatlı su', 'Göl, baraj, gölet, akarsu');

  final String ad;
  final String aciklama;
  const MeraTuru(this.ad, this.aciklama);
}

class MeraOnerisi {
  final int id;
  final MeraTuru tur;
  final String ad;
  final double lat, lon;
  final String il, ilce;
  final List<String> baliklar, teknikler;
  final String dip, derinlik, zaman, erisim, notlar;
  /// Yalnızca üye adının gösterilmesine izin verdiyse dolu
  final String? oneren;

  const MeraOnerisi({
    required this.id,
    required this.tur,
    required this.ad,
    required this.lat,
    required this.lon,
    this.il = '',
    this.ilce = '',
    this.baliklar = const [],
    this.teknikler = const [],
    this.dip = '',
    this.derinlik = '',
    this.zaman = '',
    this.erisim = '',
    this.notlar = '',
    this.oneren,
  });

  static List<String> _l(Object? v) => v is List ? v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList() : const [];
  static double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory MeraOnerisi.fromJson(Map<String, dynamic> j) => MeraOnerisi(
        id: _d(j['id']).round(),
        tur: '${j['tur']}' == 'tatli' ? MeraTuru.tatli : MeraTuru.tuzlu,
        ad: '${j['ad'] ?? ''}'.trim(),
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        il: '${j['il'] ?? ''}',
        ilce: '${j['ilce'] ?? ''}',
        baliklar: _l(j['baliklar']),
        teknikler: _l(j['teknikler']),
        dip: '${j['dip'] ?? ''}'.replaceAll(',', ', '),
        derinlik: '${j['derinlik'] ?? ''}',
        zaman: '${j['zaman'] ?? ''}'.replaceAll(',', ', '),
        erisim: '${j['erisim'] ?? ''}',
        notlar: '${j['notlar'] ?? ''}',
        oneren: (j['oneren'] is String && '${j['oneren']}'.trim().isNotEmpty) ? '${j['oneren']}'.trim() : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tur': tur.name,
        'ad': ad,
        'lat': lat,
        'lon': lon,
        'il': il,
        'ilce': ilce,
        'baliklar': baliklar,
        'teknikler': teknikler,
        'dip': dip,
        'derinlik': derinlik,
        'zaman': zaman,
        'erisim': erisim,
        'notlar': notlar,
        'oneren': oneren,
      };

  String get yer => [ilce, il].where((e) => e.trim().isNotEmpty).join(', ');

  /// "Bu mera Ali Yılmaz tarafından önerildi"
  String? get onerenYazisi => oneren == null ? null : 'Bu mera $oneren tarafından önerildi';

  /// Tuzlu su önerisi Mera Bilgisi'nde nokta mera gibi açılır (tahmin kendi koordinatından)
  Spot get spot {
    final (yakin, _) = Locate.nearest(lat, lon);
    return Spot.pin(lat, lon, yakin, ad: ad);
  }
}

/// Sunucu: onaylı öneriler ve yeni öneri gönderme
class MeraOnerApi {
  static Uri _uri(Map<String, String> q) => Uri.parse('${AppConfig.siteUrl}mobil-kiyidabiri.php').replace(queryParameters: q);
  static const _onbellekAnahtari = 'mera_oneri_onayli_v1';

  /// Onaylı öneriler (uygulama açılışında yüklenir; ağ yoksa son kayıt)
  static final onaylilar = ValueNotifier<List<MeraOnerisi>>(const []);

  static Future<void> yukle() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      final s = p.getString(_onbellekAnahtari);
      if (s != null) onaylilar.value = _coz(jsonDecode(s));
    } catch (_) {}
    try {
      final r = await http.get(_uri({'a': 'oneriler'}), headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true && j['items'] is List) {
        onaylilar.value = _coz(j['items']);
        await p?.setString(_onbellekAnahtari, jsonEncode(onaylilar.value.map((e) => e.toJson()).toList()));
      }
    } catch (_) {}
  }

  static List<MeraOnerisi> _coz(Object? l) => l is List
      ? l.whereType<Map>().map((e) => MeraOnerisi.fromJson(Map<String, dynamic>.from(e))).where((e) => e.ad.isNotEmpty).toList()
      : const [];

  static List<MeraOnerisi> turu(MeraTuru t) => onaylilar.value.where((e) => e.tur == t).toList();

  /// Öneriyi gönderir; başarılıysa sunucunun teşekkür mesajını döndürür
  static Future<String> gonder(String token, Map<String, String> alanlar) async {
    try {
      final r = await http
          .post(_uri({'a': 'oner'}),
              headers: {'Accept': 'application/json', 'X-Av-Anahtar': token},
              body: {...alanlar, 'platform': Platform.isIOS ? 'ios' : 'android'})
          .timeout(const Duration(seconds: 20));
      Object? j;
      try {
        j = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        throw 'Sunucu beklenmeyen bir yanıt verdi (kod ${r.statusCode}). Biraz sonra tekrar dene.';
      }
      if (j is Map && j['ok'] == true) return '${j['mesaj'] ?? 'Önerin alındı.'}';
      if (j is Map && j['giris'] == true) await CatchService.saveToken(null);
      throw j is Map ? '${j['error'] ?? 'Öneri gönderilemedi.'}' : 'Öneri gönderilemedi.';
    } on TimeoutException {
      throw 'Bağlantı çok yavaş. Tekrar dene.';
    } on SocketException {
      throw 'İnternet bağlantısı yok.';
    } on http.ClientException {
      throw 'Sunucuya ulaşılamadı. Biraz sonra tekrar dene.';
    }
  }
}

// ======================================================================= seçenekler
const _tuzluBaliklar = [
  'Levrek', 'Lüfer / Çinekop', 'Çipura', 'Sargoz', 'Karagöz', 'İstavrit', 'Kolyoz', 'Palamut', 'Kefal', 'Mırmır',
  'İsparoz', 'Eşkina', 'Zargana', 'Mezgit', 'Barbunya', 'Kalkan', 'Akya', 'Mürekkep balığı', 'Kalamar'
];
const _tatliBaliklar = [
  'Sazan', 'Turna', 'Levrek (tatlı su)', 'Alabalık', 'Kızılkanat', 'Tatlı su kefali', 'Yayın', 'Sudak', 'Akbalık',
  'Tahta balığı', 'Siraz', 'Kadife', 'Karabalık'
];
const _tuzluTeknik = ['LRF', 'Spin', 'Surf', 'Çapari', 'Kurşun arkası', 'Şamandıra', 'Shore jigging', 'Eging (kalamar)', 'Dip takımı'];
const _tatliTeknik = ['Spin', 'Şamandıra', 'Dip / Feeder', 'Sazan takımı (boilie)', 'Fly', 'Kurşun arkası', 'LRF / UL'];
const _tuzluDip = ['Kum', 'Çakıl', 'Kaya', 'Kum–kaya geçişi', 'Çamur', 'Yosun / çayır', 'Mendirek / taş dolgu', 'İskele'];
const _tatliDip = ['Çamur', 'Kum', 'Taşlık', 'Sazlık', 'Batık ağaç', 'Akıntılı', 'Dik kıyı'];
const _zamanlar = ['Sabah', 'Gündüz', 'Akşam', 'Gece'];

// ======================================================================= Öneri listesi
/// Topluluk meraları (onaylı öneriler) + "Mera öner" düğmesi
class MeraOnerileriEkrani extends StatefulWidget {
  final MeraTuru tur;
  const MeraOnerileriEkrani({super.key, this.tur = MeraTuru.tuzlu});

  @override
  State<MeraOnerileriEkrani> createState() => _MeraOnerileriEkraniState();
}

class _MeraOnerileriEkraniState extends State<MeraOnerileriEkrani> {
  @override
  void initState() {
    super.initState();
    MeraOnerApi.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.tur.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Topluluk meraları'),
          bottom: const TabBar(tabs: [Tab(text: 'Tuzlu su'), Tab(text: 'Tatlı su')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            backgroundColor: Tide.turuncu,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Mera öner'),
            onPressed: () => meraOner(ctx, MeraTuru.values[DefaultTabController.of(ctx).index]),
          ),
        ),
        body: ValueListenableBuilder<List<MeraOnerisi>>(
          valueListenable: MeraOnerApi.onaylilar,
          builder: (context, _, __) => TabBarView(children: [
            for (final t in MeraTuru.values) _liste(context, MeraOnerApi.turu(t), t),
          ]),
        ),
      ),
    );
  }

  Widget _liste(BuildContext context, List<MeraOnerisi> l, MeraTuru t) {
    if (l.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 40),
        const Icon(Icons.travel_explore, size: 56, color: Tide.misina),
        const SizedBox(height: 12),
        Text('Henüz onaylı ${t.ad.toLowerCase()} önerisi yok.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Bildiğin bir merayı öner; yönetici onayından sonra burada herkes görsün.',
            textAlign: TextAlign.center, style: TextStyle(color: Tide.misina)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: l.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => MeraOnerisiKarti(oneri: l[i]),
    );
  }
}

class MeraOnerisiKarti extends StatelessWidget {
  final MeraOnerisi oneri;
  const MeraOnerisiKarti({super.key, required this.oneri});

  @override
  Widget build(BuildContext context) {
    final o = oneri;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(o.tur == MeraTuru.tatli ? Icons.water : Icons.waves, color: Tide.turuncu),
          const SizedBox(width: 8),
          Expanded(
            child: Text(o.ad, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (o.yer.isNotEmpty) Text(o.yer, style: const TextStyle(color: Tide.misina, fontSize: 13)),
        const SizedBox(height: 8),
        if (o.baliklar.isNotEmpty) _satir('Balıklar', o.baliklar.join(', ')),
        if (o.teknikler.isNotEmpty) _satir('Teknik', o.teknikler.join(', ')),
        if (o.dip.isNotEmpty) _satir('Dip', o.dip),
        if (o.derinlik.isNotEmpty) _satir('Derinlik', o.derinlik),
        if (o.zaman.isNotEmpty) _satir('Verimli zaman', o.zaman),
        if (o.erisim.isNotEmpty) _satir('Ulaşım', o.erisim),
        if (o.notlar.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(o.notlar, style: const TextStyle(height: 1.35)),
          ),
        if (o.onerenYazisi != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: Tide.zeytinKoyu),
              const SizedBox(width: 6),
              Expanded(
                child: Text(o.onerenYazisi!,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Tide.zeytinKoyu, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (o.tur == MeraTuru.tuzlu)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Tide.derin),
              icon: const Icon(Icons.insights, size: 18),
              label: const Text('Mera bilgisini aç'),
              onPressed: () async {
                final s = o.spot;
                await Meralarim.ekle(s);
                await Locate.manualPick(s);
                if (!context.mounted) return;
                Navigator.of(context).popUntil((r) => r.isFirst);
                shellTab.value = Shell.tabReport;
              },
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.push_pin_outlined, size: 18),
            label: const Text('Nokta meralarıma ekle'),
            onPressed: () async {
              await Meralarim.ekle(o.spot);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('${o.ad} nokta meralarına eklendi.')));
              }
            },
          ),
        ]),
      ]),
    );
  }

  Widget _satir(String b, String m) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          style: const TextStyle(color: Color(0xFF2B2A20), fontSize: 14, height: 1.3),
          TextSpan(children: [
            TextSpan(text: '$b: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: m),
          ]),
        ),
      );
}

// ======================================================================= Öneri formu
/// Üyelik doğrulanır, form açılır
Future<void> meraOner(BuildContext context, MeraTuru tur) async {
  final t = await ensureCatchToken(context);
  if (!context.mounted) return;
  if (t == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mera önermek için üye girişi gerekli. Hesabım › Giriş yap ile giriş yapıp tekrar dene.')));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeraOnerFormu(tur: tur, token: t)));
}

class MeraOnerFormu extends StatefulWidget {
  final MeraTuru tur;
  final String token;
  const MeraOnerFormu({super.key, required this.tur, required this.token});

  @override
  State<MeraOnerFormu> createState() => _MeraOnerFormuState();
}

class _MeraOnerFormuState extends State<MeraOnerFormu> {
  late MeraTuru _tur = widget.tur;
  final _ad = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _derinlik = TextEditingController();
  final _erisim = TextEditingController();
  final _notlar = TextEditingController();
  final _baliklar = <String>{};
  final _teknikler = <String>{};
  final _dip = <String>{};
  final _zaman = <String>{};
  LatLng? _konum;
  bool _adGoster = false;
  bool _gonderiliyor = false;

  @override
  void dispose() {
    for (final c in [_ad, _il, _ilce, _derinlik, _erisim, _notlar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _haritadanSec() async {
    final s = await Navigator.of(context).push<Spot>(MaterialPageRoute(
        builder: (_) => HaritaSecici(
            baslik: 'Meranın yerini işaretle',
            baslangic: _konum ?? LatLng(selectedSpot.value.lat, selectedSpot.value.lon),
            secYazisi: 'Bu noktayı kullan',
            liste: false)));
    if (s == null || !mounted) return;
    setState(() => _konum = LatLng(s.lat, s.lon));
    // Yer adı (il / ilçe) ve boşsa mera adı haritadan önerilir
    final ad = await Meralarim.yerAdi(s.lat, s.lon);
    if (ad == null || !mounted) return;
    final parca = ad.$1.split(',').map((e) => e.trim()).toList();
    setState(() {
      if (_ad.text.trim().isEmpty) _ad.text = parca.first;
      if (_ilce.text.trim().isEmpty && parca.length > 1) _ilce.text = parca.last;
    });
  }

  Future<void> _gonder() async {
    final ad = _ad.text.trim();
    String? hata;
    if (ad.length < 3) {
      hata = 'Meranın adını yaz.';
    } else if (_konum == null) {
      hata = 'Haritada meranın yerini işaretle.';
    } else if (_baliklar.isEmpty) {
      hata = 'En az bir balık türü seç.';
    }
    if (hata != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    setState(() => _gonderiliyor = true);
    try {
      final m = await MeraOnerApi.gonder(widget.token, {
        'tur': _tur.name,
        'ad': ad,
        'lat': _konum!.latitude.toStringAsFixed(5),
        'lon': _konum!.longitude.toStringAsFixed(5),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'baliklar': _baliklar.join(','),
        'teknikler': _teknikler.join(','),
        'dip': _dip.join(','),
        'derinlik': _derinlik.text.trim(),
        'zaman': _zaman.join(','),
        'erisim': _erisim.text.trim(),
        'notlar': _notlar.text.trim(),
        'ad_goster': _adGoster ? '1' : '0',
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
          title: const Text('Önerin alındı'),
          content: Text(m),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tamam'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Hata.goster(e);
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tuzlu = _tur == MeraTuru.tuzlu;
    return Scaffold(
      appBar: AppBar(title: const Text('Mera öner')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        SegmentedButton<MeraTuru>(
          segments: [
            for (final t in MeraTuru.values)
              ButtonSegment(
                  value: t,
                  label: Text(t.ad),
                  icon: Icon(t == MeraTuru.tatli ? Icons.water : Icons.waves)),
          ],
          selected: {_tur},
          onSelectionChanged: (s) => setState(() {
            _tur = s.first;
            _baliklar.clear();
            _teknikler.clear();
            _dip.clear();
          }),
        ),
        const SizedBox(height: 6),
        Text(_tur.aciklama, style: const TextStyle(color: Tide.misina, fontSize: 12.5)),
        const SizedBox(height: 14),
        TextField(
          controller: _ad,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
              labelText: 'Meranın adı *',
              hintText: tuzlu ? 'ör. Kireçburnu mendireği' : 'ör. Sapanca – Kurtköy kıyısı',
              border: const OutlineInputBorder()),
        ),
        // Konum
        Material(
          color: _konum == null ? const Color(0xFFFFF4EC) : const Color(0xFFEAF6EE),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: Icon(_konum == null ? Icons.add_location_alt_outlined : Icons.where_to_vote,
                color: _konum == null ? Tide.turuncu : Colors.green),
            title: Text(_konum == null ? 'Haritada yerini işaretle *' : 'Konum işaretlendi',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_konum == null
                ? 'İğneyi tam balık tuttuğun noktaya bırak'
                : '${_konum!.latitude.toStringAsFixed(5)}, ${_konum!.longitude.toStringAsFixed(5)} · değiştirmek için dokun'),
            trailing: const Icon(Icons.map_outlined),
            onTap: _haritadanSec,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _il,
                  decoration: const InputDecoration(labelText: 'İl', border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _ilce,
                  decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()))),
        ]),
        _baslik('Hangi balıklar çıkıyor? *'),
        _secimler(tuzlu ? _tuzluBaliklar : _tatliBaliklar, _baliklar),
        _baslik('Teknik'),
        _secimler(tuzlu ? _tuzluTeknik : _tatliTeknik, _teknikler),
        _baslik('Dip / kıyı yapısı'),
        _secimler(tuzlu ? _tuzluDip : _tatliDip, _dip),
        _baslik('En verimli zaman'),
        _secimler(_zamanlar, _zaman),
        const SizedBox(height: 12),
        TextField(
          controller: _derinlik,
          maxLength: 60,
          decoration: const InputDecoration(
              labelText: 'Yaklaşık derinlik / atış mesafesi',
              hintText: 'ör. 40 m açıkta 6–8 m',
              border: OutlineInputBorder()),
        ),
        TextField(
          controller: _erisim,
          maxLength: 200,
          decoration: const InputDecoration(
              labelText: 'Ulaşım ve park', hintText: 'ör. Sahil yolundan 5 dk yürüyüş', border: OutlineInputBorder()),
        ),
        TextField(
          controller: _notlar,
          maxLength: 800,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Notlar',
              hintText: 'Yem, mevsim, dikkat edilecekler… (telefon numarası ve bağlantı yazma)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        // İsim gösterme izni (açık rıza)
        Material(
          color: const Color(0xFFF7F5EE),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE6E2D6))),
          child: CheckboxListTile(
            value: _adGoster,
            onChanged: (v) => setState(() => _adGoster = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Adım ve soyadım öneride görünsün', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Onaylanırsa merada "Bu mera <Adın Soyadın> tarafından önerildi" yazar. Ad, KıyıdanAv üyeliğindeki '
                'kayıtlı adından alınır. İşaretlemezsen adın hiçbir yerde görünmez. İznini istediğin zaman '
                'WhatsApp destek hattından geri alabilirsin.',
                style: TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size.fromHeight(50)),
          onPressed: _gonderiliyor ? null : _gonder,
          icon: _gonderiliyor
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: const Text('Öneriyi gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        const Text('Öneriler yönetici onayından sonra "Topluluk meraları" bölümünde yayınlanır.',
            textAlign: TextAlign.center, style: TextStyle(color: Tide.misina, fontSize: 12)),
      ]),
    );
  }

  Widget _baslik(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.zeytinKoyu, fontSize: 14.5)),
      );

  Widget _secimler(List<String> l, Set<String> secili) => Wrap(spacing: 8, runSpacing: 4, children: [
        for (final s in l)
          FilterChip(
            label: Text(s),
            selected: secili.contains(s),
            selectedColor: Tide.somon,
            onSelected: (v) => setState(() => v ? secili.add(s) : secili.remove(s)),
          ),
      ]);
}

// ======================================================================= Mera Bilgisi kartı
/// Mera Bilgisi'nde "Kural oluştur" ile "Bugün balık kaç metrede?" arasındaki kart
class MeraOnerGirisKarti extends StatelessWidget {
  const MeraOnerGirisKarti({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Tide.derin, Color(0xFF15535E)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Tide.turuncu, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mera öner · Topluluk meraları',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Bildiğin merayı paylaş, balıkçıların önerdiği meraları keşfet',
                    style: TextStyle(color: Color(0xFFBFD6D1), fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<MeraOnerisi>>(
            valueListenable: MeraOnerApi.onaylilar,
            builder: (context, l, _) => Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => _turSec(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Mera öner', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeraOnerileriEkrani())),
                  icon: const Icon(Icons.groups_2_outlined, size: 18),
                  label: Text(l.isEmpty ? 'Topluluk' : 'Topluluk (${l.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _turSec(BuildContext context) async {
    final t = await showModalBottomSheet<MeraTuru>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Hangi merayı önereceksin?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final t in MeraTuru.values)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Tide.somon, child: Icon(t == MeraTuru.tatli ? Icons.water : Icons.waves, color: Tide.zeytinKoyu)),
              title: Text(t.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t.aciklama),
              onTap: () => Navigator.of(ctx).pop(t),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (t != null && context.mounted) await meraOner(context, t);
  }
}
