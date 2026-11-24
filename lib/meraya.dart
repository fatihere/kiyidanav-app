import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'acilis.dart';
import 'sea.dart';
import 'theme.dart';

/// 1.18.0: Mera Bilgisi'nde "Meraya git" kartı: yol tarifi, yakın otoparklar, mera kamerası, kalabalık bildirimi.
/// Veriler kiyidanav.com/mobil-meraya.php'den gelir (otopark: OpenStreetMap; kamera: belediye/yayıncı sayfasına bağlantı).
const merayaUrl = 'https://www.kiyidanav.com/mobil-meraya.php';

class MerayaOtopark {
  final String ad;
  final double lat, lon;
  final int mesafeM;
  final String ucret, tur;
  final int kapasite;
  const MerayaOtopark(this.ad, this.lat, this.lon, this.mesafeM, {this.ucret = '', this.tur = '', this.kapasite = 0});
  factory MerayaOtopark.json(Map<String, dynamic> j) => MerayaOtopark(
        (j['ad'] ?? '').toString(),
        (j['lat'] as num?)?.toDouble() ?? 0,
        (j['lon'] as num?)?.toDouble() ?? 0,
        (j['mesafe_m'] as num?)?.toInt() ?? 0,
        ucret: (j['ucret'] ?? '').toString(),
        tur: (j['tur'] ?? '').toString(),
        kapasite: (j['kapasite'] as num?)?.toInt() ?? 0,
      );
  String get baslik => ad.isEmpty ? 'Otopark' : ad;
  String get alt => [
        mesafeYazi(mesafeM),
        if (tur.isNotEmpty && tur != 'açık') tur,
        if (ucret.isNotEmpty) ucret,
        if (kapasite > 0) '$kapasite araç',
      ].join(' · ');
}

class MerayaKamera {
  final String ad, kaynak, url, kapali;
  final int mesafeM;
  final bool resmi;
  const MerayaKamera(this.ad, this.kaynak, this.url, this.mesafeM, {this.kapali = '', this.resmi = true});
  factory MerayaKamera.json(Map<String, dynamic> j) => MerayaKamera(
        (j['ad'] ?? '').toString(),
        (j['kaynak'] ?? '').toString(),
        (j['url'] ?? '').toString(),
        (j['mesafe_m'] as num?)?.toInt() ?? 0,
        kapali: (j['kapali'] ?? '').toString(),
        resmi: j['resmi'] != false,
      );
  bool get acik => kapali.isEmpty;
}

class MerayaYogunluk {
  final int sakin, normal, kalabalik;
  final int? sonDk;
  const MerayaYogunluk(this.sakin, this.normal, this.kalabalik, [this.sonDk]);
  factory MerayaYogunluk.json(Map<String, dynamic>? j) => MerayaYogunluk(
        (j?['sakin'] as num?)?.toInt() ?? 0,
        (j?['normal'] as num?)?.toInt() ?? 0,
        (j?['kalabalik'] as num?)?.toInt() ?? 0,
        (j?['son_dk'] as num?)?.toInt(),
      );
  int get toplam => sakin + normal + kalabalik;

  /// En çok bildirilen düzey (eşitlikte kalabalık öne geçer: tedbirli olan doğru)
  int? get baskin {
    if (toplam == 0) return null;
    final l = [sakin, normal, kalabalik];
    var b = 2;
    for (var i = 2; i >= 0; i--) {
      if (l[i] > l[b]) b = i;
    }
    return b;
  }

  String get ozet {
    final b = baskin;
    if (b == null) return 'Son 2 saatte bildirim yok. İlk bildiren sen ol.';
    final ne = sonDk == null ? '' : (sonDk! < 1 ? ' (en son az önce)' : ' (en son $sonDk dk önce)');
    return '${seviyeAdi[b]} · son 2 saatte $toplam bildirim$ne';
  }
}

const seviyeAdi = ['Sakin', 'Normal', 'Kalabalık'];
const seviyeRenk = [Tide.yosun, Tide.altin, Tide.mercan];

class MerayaOzet {
  final List<MerayaOtopark> otopark;
  final bool otoparkHata;
  final List<MerayaKamera> kamera;
  final MerayaYogunluk yogunluk;
  const MerayaOzet(this.otopark, this.kamera, this.yogunluk, {this.otoparkHata = false});
  factory MerayaOzet.json(Map<String, dynamic> j) => MerayaOzet(
        [for (final o in (j['otopark'] as List? ?? const [])) MerayaOtopark.json(Map<String, dynamic>.from(o as Map))],
        [for (final k in (j['kamera'] as List? ?? const [])) MerayaKamera.json(Map<String, dynamic>.from(k as Map))],
        MerayaYogunluk.json(j['yogunluk'] == null ? null : Map<String, dynamic>.from(j['yogunluk'] as Map)),
        otoparkHata: j['otopark_hata'] == true,
      );
  MerayaKamera? get ilkAcikKamera => kamera.where((k) => k.acik).firstOrNull;
}

String mesafeYazi(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

/// Yol tarifi bağlantıları (araçla)
Uri googleYol(double lat, double lon) =>
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lon', 'travelmode': 'driving'});
Uri yandexYol(double lat, double lon) => Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lon');
Uri yandexWebYol(double lat, double lon) =>
    Uri.https('yandex.com.tr', '/harita/', {'rtext': '~$lat,$lon', 'rtt': 'auto'});
Uri appleYol(double lat, double lon) => Uri.https('maps.apple.com', '/', {'daddr': '$lat,$lon', 'dirflg': 'd'});

class MerayaApi {
  static final Map<String, MerayaOzet> _onbellek = {};
  static String _anahtar(double lat, double lon) => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  static Future<MerayaOzet> ozet(double lat, double lon, {bool yenile = false}) async {
    final k = _anahtar(lat, lon);
    if (!yenile && _onbellek[k] != null) return _onbellek[k]!;
    final r = await http
        .get(Uri.parse(merayaUrl).replace(queryParameters: {'islem': 'ozet', 'lat': '$lat', 'lon': '$lon'}))
        .timeout(const Duration(seconds: 40));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['ok'] != true) throw Exception(j['error'] ?? 'hata');
    return _onbellek[k] = MerayaOzet.json(j);
  }

  static Future<String> _cihaz() async {
    final p = await SharedPreferences.getInstance();
    var k = p.getString('kav_kurulum_kimligi') ?? '';
    if (k.length != 32) {
      k = Acilis.yeniKimlik();
      await p.setString('kav_kurulum_kimligi', k);
    }
    return k;
  }

  static Future<MerayaYogunluk> bildir(double lat, double lon, int seviye) async {
    final r = await http.post(Uri.parse(merayaUrl), body: {
      'islem': 'bildir',
      'lat': '$lat',
      'lon': '$lon',
      'seviye': '$seviye',
      'cihaz': await _cihaz(),
    }).timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (j['ok'] != true) throw Exception(j['error'] ?? 'hata');
    final y = MerayaYogunluk.json(Map<String, dynamic>.from(j['yogunluk'] as Map));
    final k = _anahtar(lat, lon);
    final eski = _onbellek[k];
    if (eski != null) _onbellek[k] = MerayaOzet(eski.otopark, eski.kamera, y, otoparkHata: eski.otoparkHata);
    return y;
  }
}

/// Yol tarifi: uygulama seçimi (Google Haritalar, Yandex Navigasyon, iPhone'da Apple Haritalar)
Future<void> yolTarifiAc(BuildContext context, double lat, double lon, String ad) async {
  final secim = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('$ad için yol tarifi',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
        ),
        ListTile(
          leading: const Icon(Icons.map, color: Tide.derin),
          title: const Text('Google Haritalar', style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.of(ctx).pop('google'),
        ),
        ListTile(
          leading: const Icon(Icons.navigation, color: Tide.mercan),
          title: const Text('Yandex Navigasyon', style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: () => Navigator.of(ctx).pop('yandex'),
        ),
        if (Platform.isIOS)
          ListTile(
            leading: const Icon(Icons.directions_car, color: Tide.kaya),
            title: const Text('Apple Haritalar', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.of(ctx).pop('apple'),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (secim == null) return;
  final dis = LaunchMode.externalApplication;
  switch (secim) {
    case 'yandex':
      final ok = await launchUrl(yandexYol(lat, lon), mode: dis).catchError((_) => false);
      if (!ok) await launchUrl(yandexWebYol(lat, lon), mode: dis);
    case 'apple':
      await launchUrl(appleYol(lat, lon), mode: dis);
    default:
      await launchUrl(googleYol(lat, lon), mode: dis);
  }
}

/// Mera Bilgisi kartı
class MerayaGitKarti extends StatefulWidget {
  final Spot spot;
  const MerayaGitKarti({super.key, required this.spot});

  @override
  State<MerayaGitKarti> createState() => _MerayaGitKartiState();
}

class _MerayaGitKartiState extends State<MerayaGitKarti> {
  Future<MerayaOzet>? _f;
  String? _icin;
  String _acik = ''; // 'otopark' | 'kamera' | ''
  MerayaYogunluk? _yeniY;
  int? _benimBildirim;
  bool _gonderiliyor = false;

  double get _lat => widget.spot.lat;
  double get _lon => widget.spot.lon;

  void _yukle({bool yenile = false}) {
    _icin = '$_lat,$_lon';
    _yeniY = null;
    _benimBildirim = null;
    _f = MerayaApi.ozet(_lat, _lon, yenile: yenile);
  }

  Future<void> _bildir(int s) async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    try {
      final y = await MerayaApi.bildir(_lat, _lon, s);
      if (!mounted) return;
      setState(() {
        _yeniY = y;
        _benimBildirim = s;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Teşekkürler! "${seviyeAdi[s]}" bildirimin diğer balıkçılara gösterilecek.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('cok')
              ? 'Çok fazla bildirim gönderildi, biraz sonra tekrar dene.'
              : 'Bildirim gönderilemedi. İnternet bağlantını kontrol et.')));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_icin != '$_lat,$_lon') _yukle();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E2D6)),
        ),
        child: FutureBuilder<MerayaOzet>(
          future: _f,
          builder: (context, snap) {
            final o = snap.data;
            final yukleniyor = snap.connectionState != ConnectionState.done;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Tide.turuncu, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.near_me, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Meraya git',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
                    Text(widget.spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF77766A))),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              // Üç ana düğme
              Row(children: [
                Expanded(
                  child: _Dugme(
                    ikon: Icons.directions_car,
                    yazi: 'Yol tarifi',
                    ana: true,
                    onTap: () => yolTarifiAc(context, _lat, _lon, widget.spot.name),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Dugme(
                    ikon: Icons.local_parking,
                    yazi: yukleniyor ? 'Otopark' : 'Otopark${o != null && o.otopark.isNotEmpty ? ' (${o.otopark.length})' : ''}',
                    secili: _acik == 'otopark',
                    pasif: !yukleniyor && (o == null || o.otopark.isEmpty),
                    onTap: () => setState(() => _acik = _acik == 'otopark' ? '' : 'otopark'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Dugme(
                    ikon: Icons.videocam,
                    yazi: 'Kamera',
                    secili: _acik == 'kamera',
                    pasif: !yukleniyor && (o == null || o.kamera.isEmpty),
                    onTap: () => setState(() => _acik = _acik == 'kamera' ? '' : 'kamera'),
                  ),
                ),
              ]),
              if (yukleniyor)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2, color: Tide.turuncu, backgroundColor: Color(0xFFF1EEE4)),
                )
              else if (o == null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Otopark, kamera ve kalabalık bilgisi alınamadı.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF77766A)))),
                    TextButton(onPressed: () => setState(() => _yukle(yenile: true)), child: const Text('Tekrar dene')),
                  ]),
                )
              else ...[
                if (_acik == 'otopark') _otoparklar(o),
                if (_acik == 'kamera') _kameralar(o),
                const Divider(height: 24),
                _yogunluk(_yeniY ?? o.yogunluk),
              ],
            ]);
          },
        ),
      ),
    );
  }

  Widget _otoparklar(MerayaOzet o) {
    if (o.otopark.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
            o.otoparkHata
                ? 'Otopark bilgisi şu an alınamadı, biraz sonra tekrar dene.'
                : '1,2 km içinde haritada kayıtlı otopark yok. Yol kenarına park ederken kurallara dikkat et.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF55544A))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      for (final p in o.otopark)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2F6FB3),
              child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          title: Text(p.baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(p.alt),
          trailing: const Icon(Icons.directions, color: Tide.turuncu),
          onTap: () => yolTarifiAc(context, p.lat, p.lon, p.baslik),
        ),
      const Text('Otopark bilgisi: © OpenStreetMap katkıcıları. Ücret ve açıklık saatleri değişebilir.',
          style: TextStyle(fontSize: 11, color: Color(0xFF8A887B))),
    ]);
  }

  Widget _kameralar(MerayaOzet o) {
    if (o.kamera.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
            'Bu merayı gören bir kamera yok. Kalabalık durumunu aşağıdaki balıkçı bildirimlerinden görebilirsin.',
            style: TextStyle(fontSize: 13, color: Color(0xFF55544A))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      for (final k in o.kamera)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
              radius: 16,
              backgroundColor: k.acik ? Tide.turuncu : const Color(0xFF8C8A7D),
              child: Icon(k.acik ? Icons.videocam : Icons.videocam_off, color: Colors.white, size: 18)),
          title: Text(k.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(k.acik
              ? '${k.kaynak} · ${mesafeYazi(k.mesafeM)} uzakta${k.resmi ? '' : ' · özel kamera'}'
              : 'Yayın kapalı: ${k.kapali}'),
          trailing: k.acik ? const Icon(Icons.open_in_new, color: Tide.turuncu, size: 20) : null,
          onTap: k.acik ? () => launchUrl(Uri.parse(k.url), mode: LaunchMode.externalApplication) : null,
        ),
      const Text('Canlı görüntü kameranın sahibinin sayfasında açılır; uygulama görüntüyü kaydetmez.',
          style: TextStyle(fontSize: 11, color: Color(0xFF8A887B))),
    ]);
  }

  Widget _yogunluk(MerayaYogunluk y) {
    final t = y.toplam;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Merada kalabalık', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
      const SizedBox(height: 6),
      if (t > 0)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                if ([y.sakin, y.normal, y.kalabalik][i] > 0)
                  Expanded(flex: [y.sakin, y.normal, y.kalabalik][i], child: Container(color: seviyeRenk[i])),
            ]),
          ),
        ),
      if (t > 0) const SizedBox(height: 6),
      Text(y.ozet, style: const TextStyle(fontSize: 13, color: Color(0xFF55544A))),
      const SizedBox(height: 10),
      const Text('Şu an meradaysan durumu bildir:', style: TextStyle(fontSize: 12.5, color: Color(0xFF77766A))),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: seviyeRenk[i],
                backgroundColor: _benimBildirim == i ? seviyeRenk[i].withValues(alpha: .12) : null,
                side: BorderSide(color: seviyeRenk[i], width: _benimBildirim == i ? 2 : 1),
              ),
              onPressed: _gonderiliyor ? null : () => _bildir(i),
              child: Text(seviyeAdi[i], style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    ]);
  }
}

class _Dugme extends StatelessWidget {
  final IconData ikon;
  final String yazi;
  final bool ana, secili, pasif;
  final VoidCallback onTap;
  const _Dugme(
      {required this.ikon, required this.yazi, required this.onTap, this.ana = false, this.secili = false, this.pasif = false});

  @override
  Widget build(BuildContext context) {
    final arka = ana ? Tide.turuncu : (secili ? Tide.derin : const Color(0xFFF6F4EE));
    final on = ana || secili ? Colors.white : (pasif ? const Color(0xFFA7A58E) : Tide.zeytinKoyu);
    return Material(
      color: arka,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Icon(ikon, color: on, size: 22),
            const SizedBox(height: 4),
            Text(yazi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: on)),
          ]),
        ),
      ),
    );
  }
}

/// Mera seçici listesindeki küçük yol tarifi düğmesi
class YolTarifiIkonu extends StatelessWidget {
  final Spot spot;
  const YolTarifiIkonu({super.key, required this.spot});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Yol tarifi',
        icon: const Icon(Icons.directions, color: Tide.turuncu),
        onPressed: () => yolTarifiAc(context, spot.lat, spot.lon, spot.name),
      );
}
