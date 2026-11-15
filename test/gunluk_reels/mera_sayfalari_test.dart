// kiyidanav.com/balik-durumu sayfaları için günlük veri (15.11.2026).
// Uygulamanın KENDİ hesabıyla (veri.dart › meraGunu: deniz tahmini + kesit + kıyılama) kullanıcıya açık
// tüm meraları hesaplar; build/mera_sayfalari/meralar.json yazar. İş akışı (gunluk-reels.yml › mera-sayfalari)
// dosyayı kiyidanav.com/balik-durumu/al.php'ye gönderir. Yalnız MERA_SAYFALARI=1 iken çalışır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/api.dart';
import 'package:kiyidanav/sea.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'veri.dart';

final _acik = Platform.environment['MERA_SAYFALARI'] == '1';

/// Türkçe adı adrese çevirir: "Anadolu Kavağı" -> "anadolu-kavagi"
String sluga(String s) {
  const t = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u',
    'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'I': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u'};
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(t[ch] ?? ch.toLowerCase());
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

void main() {
  testWidgets('mera sayfaları verisi', (t) async {
    final cikti = Directory(Platform.environment['MERA_SAYFALARI_CIKTI'] ?? 'build/mera_sayfalari')..createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null; // gerçek ağ

    final sonuc = await t.runAsync(() async {
      await Api.loadConfig();
      final now = DateTime.now();
      final harita = IlHaritasi.dosyadan();
      final adaylar = spots.where((s) => !s.custom).toList();
      final out = <Map<String, Object?>>[];
      final slugSay = <String, int>{};
      // aynı anda 6 mera (açık deniz servislerini yormadan)
      for (var i = 0; i < adaylar.length; i += 6) {
        final grup = adaylar.skip(i).take(6).toList();
        final sonuclar = await Future.wait(grup.map((s) async {
          final il = harita.meraIli(s);
          return (s, il, await meraGunu(s, now, il: il));
        }));
        for (final (s, il, m) in sonuclar) {
          if (m == null || il.isEmpty) continue;
          var slug = sluga(s.name);
          final n = (slugSay[slug] ?? 0) + 1;
          slugSay[slug] = n;
          if (n > 1) slug = '$slug-${sluga(il)}';
          final j = m.json();
          // kesit: sayfadaki çizim için en çok 40 nokta
          final kesit = (j['kesit'] as List?) ?? const [];
          final adim = kesit.length > 40 ? (kesit.length / 40).ceil() : 1;
          out.add({
            ...j,
            'slug': slug,
            'il_slug': sluga(il),
            'lat': s.lat,
            'lon': s.lon,
            'bogaz': s.strait,
            'kesit': [for (var k = 0; k < kesit.length; k += adim) kesit[k]],
            'gunler': [
              for (final d in m.f.days.take(4))
                {
                  'tarih': d.date.toIso8601String().substring(0, 10),
                  'ruzgar_kmh': d.windMax?.round(),
                  'dalga_m': d.waveMax == null ? null : double.parse(d.waveMax!.toStringAsFixed(1)),
                  'yagis_ihtimal': d.rainProb,
                  'gun_dogumu': d.sunrise?.toIso8601String().substring(11, 16),
                  'gun_batimi': d.sunset?.toIso8601String().substring(11, 16),
                }
            ],
          });
        }
        // ignore: avoid_print
        print('mera ${i + grup.length}/${adaylar.length}');
      }
      File('${cikti.path}/meralar.json').writeAsStringSync(jsonEncode({
        'surum': 1,
        'zaman': now.toIso8601String(),
        'meralar': out,
      }));
      return out.length;
    });
    // ignore: avoid_print
    print('yazılan mera: $sonuc');
    expect(sonuc, greaterThan(20), reason: 'yeterli mera verisi gelmedi');
  }, skip: !_acik, timeout: const Timeout(Duration(minutes: 40)));

  test('mera adresi', () {
    expect(sluga('Anadolu Kavağı'), 'anadolu-kavagi');
    expect(sluga('Şile – Ağva'), 'sile-agva');
    expect(sluga('İğneada'), 'igneada');
  });
}
