import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/gelgit.dart';
import 'package:kiyidanav/premium.dart';

void main() {
  group('Ücretsiz / premium', () {
    tearDown(() {
      Premium.ayar = const PremiumAyar();
      Premium.aktif.value = false;
    });

    test('sistem kapalıyken her şey açık', () {
      Premium.yukle({
        'premium': {'acik': false, 'paneller': {'uydu': 'premium', 'dugum': 'kapali'}, 'gunler': [true, false, false, false, false, false, false]},
      });
      expect(Premium.panel('uydu'), PanelDurum.acik);
      expect(Premium.panel('dugum'), PanelDurum.acik);
      expect(Premium.gunAcik(5), isTrue);
      expect(Premium.bilgi(), PanelDurum.acik);
    });

    test('açıkken premium paneller kilitli, kapalılar gizli, günler ayrı ayrı', () {
      Premium.yukle({
        'premium': {
          'acik': true,
          'paneller': {'rapor': 'ucretsiz', 'uydu': 'premium', 'dugum': 'kapali', 'kotu': 'bilinmeyen'},
          'gunler': [true, true, false, false, false, false, false],
          'bilgi': 'premium',
          'urunler': ['kiyidanav_premium'],
        },
      });
      expect(Premium.panel('rapor'), PanelDurum.acik);
      expect(Premium.panel('uydu'), PanelDurum.kilitli);
      expect(Premium.panel('dugum'), PanelDurum.gizli);
      expect(Premium.panel('tanimsiz'), PanelDurum.acik);
      expect(Premium.gunAcik(0), isTrue);
      expect(Premium.gunAcik(1), isTrue);
      expect(Premium.gunAcik(2), isFalse);
      expect(Premium.bilgi(), PanelDurum.kilitli);
      expect(Premium.ayar.urunler, ['kiyidanav_premium']);

      Premium.aktif.value = true; // abone ya da panelden verilen hak
      expect(Premium.panel('uydu'), PanelDurum.acik);
      expect(Premium.panel('dugum'), PanelDurum.gizli);
      expect(Premium.gunAcik(6), isTrue);
      expect(Premium.bilgi(), PanelDurum.acik);
    });

    test('eksik ya da bozuk ayar güvenli varsayılana döner', () {
      Premium.yukle({'premium': 'bozuk'});
      expect(Premium.ayar.acik, isFalse);
      Premium.yukle({'premium': {'acik': true, 'gunler': [false]}});
      expect(Premium.ayar.gunler.length, 7);
      expect(Premium.gunAcik(0), isFalse);
      expect(Premium.gunAcik(3), isTrue);
    });
  });

  group('Gelgit', () {
    // 00:00'dan itibaren 48 saatlik yarım günlük (12,42 sa) gelgit: genlik 0,2 m
    final bas = DateTime(2026, 10, 14);
    final zaman = [for (var i = 0; i < 48; i++) bas.add(Duration(hours: i))];
    final seviye = <double?>[for (var i = 0; i < 48; i++) 0.2 * math.sin((i - 3) / 12.42 * 2 * math.pi)];

    test('en düşük / en yüksek saat ve seviye', () {
      final o = gelgitOzet(zaman, seviye, DateTime(2026, 10, 14, 9, 30))!;
      expect(o.farkCm, greaterThan(35));
      expect(o.enYuksekCm, greaterThan(15));
      expect(o.enDusukCm, lessThan(-15));
      expect(o.enYuksekSaat.hour, anyOf(6, 18, 19));
      expect(o.enDusukSaat.hour, anyOf(0, 12, 13, 24));
      expect(o.seri.length, 25);
      expect(['düşük', 'ortalama', 'yüksek'], contains(o.seviye));
      expect(gelgitYorum(o, 'Kartal'), contains('gelgit'));
    });

    test('yükseliyor / alçalıyor', () {
      expect(gelgitOzet(zaman, seviye, DateTime(2026, 10, 14, 3))!.yukseliyor, isTrue);
      expect(gelgitOzet(zaman, seviye, DateTime(2026, 10, 14, 9))!.yukseliyor, isFalse);
    });

    test('küçük farkta "belirgin değişmiyor"', () {
      final az = [for (final v in seviye) v! * 0.1];
      final o = gelgitOzet(zaman, az, DateTime(2026, 10, 14, 10))!;
      expect(o.belirsiz(10), isTrue);
      expect(gelgitYorum(o, 'Kilyos'), contains('belirgin değişmiyor'));
    });

    test('veri yoksa kart çıkmaz', () {
      expect(gelgitOzet(const [], const [], DateTime(2026, 10, 14)), isNull);
    });

    test('İstanbul tür listesi', () {
      final adlar = gelgitTurleri.map((t) => t.ad).toList();
      for (final t in ['Palamut', 'Eşkina', 'Mırmır', 'Çinekop', 'Sarıkanat', 'Lüfer', 'Levrek', 'İstavrit', 'İskorpit', 'Kalkan']) {
        expect(adlar, contains(t));
      }
      for (final t in gelgitTurleri) {
        expect(t.donem, isNotEmpty);
        expect(t.ekipman, isNotEmpty);
        expect(t.ara, isNotEmpty);
      }
      final k = GelgitTur.fromJson({'tur': 'Kefal', 'metin': 'Dere ağzında', 'ekipman': 'Şamandıra'});
      expect(k.ad, 'Kefal');
      expect(k.ara, 'Kefal');
    });
  });
}
