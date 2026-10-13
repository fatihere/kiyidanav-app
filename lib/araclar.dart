import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'catches.dart';
import 'config.dart';
import 'modul_kartlari.dart';
import 'moduller.dart';
import 'push.dart';
import 'theme.dart';
import 'web_page_screen.dart';

/// Panel → Modüller'deki "Av araçları": sunucudaki araclar.php sayfaları uygulamanın içinde açılır.
class Arac {
  final String id;
  final IconData ikon;
  final String ad;
  const Arac(this.id, this.ikon, this.ad);
}

const araclarListesi = <Arac>[
  Arac('gunluk', Icons.menu_book_outlined, 'Av günlüğüm'),
  Arac('tur_tanima', Icons.photo_camera_outlined, 'Bu balık ne?'),
  Arac('ansiklopedi', Icons.auto_stories_outlined, 'Balık ansiklopedisi'),
  Arac('turnuva', Icons.emoji_events_outlined, 'Turnuvalar'),
  Arac('isi_haritasi', Icons.map_outlined, 'Av ısı haritası'),
  Arac('kosul_alarm', Icons.notifications_active_outlined, 'Koşul alarmları'),
  Arac('stok_alarm', Icons.local_offer_outlined, 'Stok ve fiyat alarmı'),
  Arac('av_puani', Icons.stars_outlined, 'Av puanım'),
  Arac('uyumluluk', Icons.link, 'Uyumluluk kontrolü'),
  Arac('hesaplayici', Icons.calculate_outlined, 'Misina hesaplayıcı'),
  Arac('yem_kutusu', Icons.inventory_2_outlined, 'Aylık yem kutusu'),
  Arac('video', Icons.play_circle_outline, 'Videolu anlatım'),
  Arac('sonar', Icons.sensors, 'Sonar haritam'),
];

class Araclar {
  /// Uygulamada açık araçlar. Üye olmayan da görür; araç giriş gerektiriyorsa sayfa girişe yönlendirir.
  static List<(Arac, ModulCfg)> acik() {
    final out = <(Arac, ModulCfg)>[];
    for (final a in araclarListesi) {
      final m = Moduller.app(a.id, uye: true);
      if (m != null) out.add((a, m));
    }
    out.sort((x, y) => x.$2.sira.compareTo(y.$2.sira));
    return out;
  }

  static String ad(Arac a, ModulCfg m) => m.baslik.isNotEmpty ? m.baslik : a.ad;

  /// Sayfa yolu: üyelik anahtarı (k) ve bildirim için cihaz kimliği (fcm) eklenir
  static Future<String> yol(String id, {Map<String, String> ek = const {}}) async {
    final q = <String, String>{'m': id, 'app': '1', ...ek};
    final t = await CatchService.token();
    if (t != null) q['k'] = t;
    final f = await Push.token();
    if (f != null) q['fcm'] = f;
    return 'araclar.php?${Uri(queryParameters: q).query}';
  }

  static Future<void> ac(BuildContext context, String id, String baslik, {Map<String, String> ek = const {}}) async {
    final p = await yol(id, ek: ek);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebPageScreen(title: baslik, path: p)));
  }
}

/// Turnuva tablosundan şu an süren turnuvalar (bitiş günü dahil)
List<Map<String, dynamic>> aktifTurnuvalar(List<Map<String, dynamic>> l, DateTime simdi) {
  final bugun = DateTime(simdi.year, simdi.month, simdi.day);
  return l.where((t) {
    final ad = '${t['ad'] ?? ''}'.trim();
    final bas = DateTime.tryParse('${t['bas'] ?? ''}');
    final bit = DateTime.tryParse('${t['bit'] ?? ''}');
    if (ad.isEmpty || bas == null || bit == null) return false;
    return !bugun.isBefore(DateTime(bas.year, bas.month, bas.day)) && !bugun.isAfter(DateTime(bit.year, bit.month, bit.day));
  }).toList();
}

/// "KA-{GÜN}" → "KA-1310" (gün + ay; sunucuyla aynı)
String gununKodu(String sablon, DateTime t) {
  final g = '${t.day.toString().padLeft(2, '0')}${t.month.toString().padLeft(2, '0')}';
  return sablon.replaceAll('{GÜN}', g).replaceAll('{GUN}', g).replaceAll('{TARIH}', '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}');
}

/// Mera raporunun altındaki "Av araçları" kartı
class AraclarKarti extends StatelessWidget {
  final String? mera;
  const AraclarKarti({super.key, this.mera});

  @override
  Widget build(BuildContext context) {
    final l = Araclar.acik();
    final set = Moduller.app('set_baglanti', uye: true);
    if (l.isEmpty && set == null) return const SizedBox.shrink();
    return ModulKart(
      m: const ModulCfg(id: 'araclar'),
      ikon: Icons.handyman_outlined,
      baslik: 'Av araçları',
      alt: 'Günlük, alarm, turnuva, hesaplayıcı…',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (set != null && mera != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: s.vurgu, minimumSize: const Size.fromHeight(44)),
              onPressed: () => Araclar.ac(context, 'set_baglanti', 'Bugün için set', ek: {'mera': mera!}),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(set.s('buton', 'Bugün için önerilen seti gör')),
            ),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (a, m) in l)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Araclar.ac(context, a.id, Araclar.ad(a, m)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(a.ikon, size: 18, color: s.vurgu),
                  const SizedBox(width: 6),
                  Text(Araclar.ad(a, m), style: TextStyle(color: s.yazi, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (m.test) ...[
                    const SizedBox(width: 4),
                    const Text('TEST', style: TextStyle(color: Color(0xFFE0A526), fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ],
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Ürün sayfası parçaları: "Bu ürünle tutuldu", stok/fiyat alarmı, uyumluluk, misina hesabı, videolar
class UrunAraclari {
  final List<Map<String, dynamic>> avlar;
  final String avBaslik;
  final String? stokButon;
  final String? uyum;
  final String? hesap;
  final List<Map<String, dynamic>> videolar;
  final String videoBaslik;
  const UrunAraclari(
      {this.avlar = const [],
      this.avBaslik = '',
      this.stokButon,
      this.uyum,
      this.hesap,
      this.videolar = const [],
      this.videoBaslik = ''});

  bool get bos => avlar.isEmpty && stokButon == null && uyum == null && hesap == null && videolar.isEmpty;

  factory UrunAraclari.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> liste(dynamic v) =>
        v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    final bu = j['buUrunle'] is Map ? j['buUrunle'] as Map : const {};
    final vi = j['video'] is Map ? j['video'] as Map : const {};
    return UrunAraclari(
      avlar: liste(bu['avlar']).where((a) => '${a['foto']}'.startsWith('https://')).toList(),
      avBaslik: '${bu['baslik'] ?? 'Bu ürünle tutuldu'}',
      stokButon: j['stok'] is Map ? '${(j['stok'] as Map)['buton'] ?? 'Haber ver'}' : null,
      uyum: j['uyum'] is Map ? '${(j['uyum'] as Map)['metin'] ?? ''}' : null,
      hesap: j['hesap'] is Map ? '${(j['hesap'] as Map)['metin'] ?? ''}' : null,
      videolar: liste(vi['liste']).where((v) => RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch('${v['id']}')).toList(),
      videoBaslik: '${vi['baslik'] ?? 'Videolu anlatım'}',
    );
  }

  static Future<UrunAraclari?> getir(int id) async {
    if (Araclar.acik().isEmpty && Moduller.app('bu_urunle', uye: true) == null) return null;
    try {
      final t = await CatchService.token();
      final uri = Uri.parse('${AppConfig.siteUrl}araclar.php').replace(queryParameters: {'api': 'urun', 'id': '$id', 'app': '1'});
      final r = await http.get(uri, headers: {'Accept': 'application/json', if (t != null) 'X-Av-Anahtar': t}).timeout(const Duration(seconds: 10));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map || j['ok'] != true) return null;
      final u = UrunAraclari.fromJson(Map<String, dynamic>.from(j));
      return u.bos ? null : u;
    } catch (_) {
      return null;
    }
  }
}

class UrunAraclariAlani extends StatefulWidget {
  final int urunId;
  const UrunAraclariAlani({super.key, required this.urunId});

  @override
  State<UrunAraclariAlani> createState() => _UrunAraclariAlaniState();
}

class _UrunAraclariAlaniState extends State<UrunAraclariAlani> {
  late final Future<UrunAraclari?> _f = UrunAraclari.getir(widget.urunId);

  Widget _satir(IconData i, String t, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(i, color: Tide.turuncu),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, color: Tide.misina),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UrunAraclari?>(
      future: _f,
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) return const SizedBox.shrink();
        final id = '${widget.urunId}';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 14),
          if (u.stokButon != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Tide.turuncu, side: const BorderSide(color: Tide.turuncu), minimumSize: const Size.fromHeight(44)),
              onPressed: () => Araclar.ac(context, 'stok_alarm', 'Haber ver', ek: {'ekle': id}),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(u.stokButon!),
            ),
          if (u.uyum != null) _satir(Icons.link, u.uyum!, () => Araclar.ac(context, 'uyumluluk', 'Uyumlu yemler', ek: {'kamis': id})),
          if (u.hesap != null) _satir(Icons.calculate_outlined, u.hesap!, () => Araclar.ac(context, 'hesaplayici', 'Misina hesaplayıcı', ek: {'makine': id})),
          if (u.avlar.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(u.avBaslik, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: u.avlar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final a = u.avlar[i];
                  return SizedBox(
                    width: 120,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network('${a['foto']}', width: 120, height: 120, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 120, height: 120, color: const Color(0xFFE9E6DC))),
                      ),
                      const SizedBox(height: 4),
                      Text('${a['balik']} · ${a['mera']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${a['ad']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Tide.misina)),
                    ]),
                  );
                },
              ),
            ),
          ],
          if (u.videolar.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(u.videoBaslik, style: Theme.of(context).textTheme.titleMedium),
            for (final v in u.videolar)
              _satir(Icons.play_circle_outline, '${v['baslik']}',
                  () => launchUrl(Uri.https('www.youtube.com', '/watch', {'v': '${v['id']}'}), mode: LaunchMode.externalApplication)),
          ],
        ]);
      },
    );
  }
}

/// Fotoğraftan tür tanıma sonucu
class TaniSonuc {
  final bool ok;
  final String hata;
  final String tur;
  final int guven;
  final bool emin;
  final double? boyTahmini;
  final double? asgariBoy;
  final String aciklama;
  final List<String> uyarilar;
  final List<String> alternatifler;
  const TaniSonuc(
      {this.ok = false,
      this.hata = '',
      this.tur = '',
      this.guven = 0,
      this.emin = false,
      this.boyTahmini,
      this.asgariBoy,
      this.aciklama = '',
      this.uyarilar = const [],
      this.alternatifler = const []});

  factory TaniSonuc.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => v is num ? v.toDouble() : null;
    List<String> l(dynamic v) => v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : const [];
    return TaniSonuc(
      ok: j['ok'] == true,
      hata: '${j['hata'] ?? ''}',
      tur: '${j['tur'] ?? ''}',
      guven: j['guven'] is num ? (j['guven'] as num).toInt() : 0,
      emin: j['emin'] == true,
      boyTahmini: d(j['boy_tahmini']),
      asgariBoy: d(j['asgari_boy']),
      aciklama: '${j['aciklama'] ?? ''}',
      uyarilar: l(j['uyarilar']),
      alternatifler: l(j['alternatifler']),
    );
  }

  static Future<TaniSonuc> gonder(String token, String fotoYolu) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.siteUrl}araclar.php?api=tani'))
        ..headers['X-Av-Anahtar'] = token
        ..headers['Accept'] = 'application/json'
        ..files.add(await http.MultipartFile.fromPath('foto', fotoYolu, filename: 'balik.jpg'));
      final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) return TaniSonuc.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {}
    return const TaniSonuc(hata: 'Tanıma şu an yapılamadı. İnternet bağlantını kontrol edip tekrar dene.');
  }
}
