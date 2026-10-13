import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/olcum_yorum.dart';

void main() {
  group('Basınç yorumu', () {
    test('hızlı düşüş: balık kıyıda, yakın mesafe', () {
      final y = Yorum.basinc(1012, -2.4);
      expect(y.aktif, 0);
      expect(y.ton, Ton.iyi);
      expect(y.mesafe, Mesafe.yakin);
      expect(y.deger, '1012 hPa ↘');
    });
    test('yavaş düşüş', () => expect(Yorum.basinc(1015, -1.0).aktif, 1));
    test('alçak ve sabit', () => expect(Yorum.basinc(1001, 0.2).aktif, 2));
    test('normal ve sabit', () {
      final y = Yorum.basinc(1015, 0.1);
      expect(y.aktif, 3);
      expect(y.deger, '1015 hPa →');
    });
    test('yüksek ve sabit: balık derinde', () {
      final y = Yorum.basinc(1024, 0.3);
      expect(y.aktif, 4);
      expect(y.ton, Ton.zayif);
      expect(y.mesafe, Mesafe.uzak);
    });
    test('yükseliyor', () => expect(Yorum.basinc(1016, 1.2).aktif, 5));
    test('hızlı yükseliyor', () => expect(Yorum.basinc(1016, 3.0).aktif, 6));
    test('eğilim yoksa yalnızca değere göre', () => expect(Yorum.basinc(1010, null).aktif, 3));
    test('veri yoksa çökmez', () => expect(Yorum.basinc(null, null).deger, '—'));
    test('her kural satırının açıklaması var', () {
      expect(Yorum.basincKurallari.length, 7);
      for (final k in Yorum.basincKurallari) {
        expect(k.$1, isNotEmpty);
        expect(k.$2, isNotEmpty);
      }
    });
  });

  group('Kırmızı alan ölçümleri', () {
    test('dalga periyodu bantları', () {
      expect(Yorum.dalgaPeriyodu(3.2, 0.4).aktif, 0);
      expect(Yorum.dalgaPeriyodu(5.0, 0.4).ton, Ton.iyi);
      expect(Yorum.dalgaPeriyodu(8.0, 0.4).aktif, 2);
    });
    test('uzun periyot + yüksek dalga tehlike uyarısı verir', () {
      final y = Yorum.dalgaPeriyodu(9.0, 1.4);
      expect(y.ton, Ton.zayif);
      expect(y.maddeler.any((m) => m.contains('DİKKAT')), isTrue);
    });
    test('bulut', () {
      expect(Yorum.bulut(100).ton, Ton.iyi);
      expect(Yorum.bulut(10).aktif, 0);
      expect(Yorum.bulut(50).aktif, 1);
    });
    test('uydu su sıcaklığı: sonbaharda soğuma olumlu', () {
      final y = Yorum.uyduSst(19.8, -1.0, 10);
      expect(y.ton, Ton.iyi);
      expect(y.aktif, 0);
      expect(y.deger, '19.8° (-1.0°)');
    });
    test('uydu su sıcaklığı: türler', () {
      expect(Yorum.uygunTurler(19.8), containsAll(['Levrek', 'Lüfer', 'Palamut', 'Mırmır']));
      expect(Yorum.uygunTurler(8), contains('Mezgit'));
      expect(Yorum.uygunTurler(8), isNot(contains('Mırmır')));
    });
    test('klorofil', () {
      expect(Yorum.klorofil(0.3, null).aktif, 0);
      expect(Yorum.klorofil(2.9, 30).durum, contains('Artıyor'));
      expect(Yorum.klorofil(12, 0).ton, Ton.zayif);
      expect(Yorum.klorofil(2.0, -25).durum, contains('Azalıyor'));
    });
    test('model uyumu', () {
      expect(Yorum.modelUyumu('Yüksek', 12, 3).ton, Ton.iyi);
      expect(Yorum.modelUyumu('Orta', 17, 3).aktif, 1);
      expect(Yorum.modelUyumu('Düşük', 25, 3).ton, Ton.zayif);
    });
    test('diğer ölçümler çökmeden yorumlanır', () {
      expect(Yorum.akinti(1.0).ton, Ton.iyi);
      expect(Yorum.dalga(null, true).deger, 'Korunaklı su');
      expect(Yorum.dalga(0.5, false).ton, Ton.iyi);
      expect(Yorum.ruzgar(14, 'Yıldız').deger, '14 km/s Yıldız');
      expect(Yorum.hamle(50).ton, Ton.zayif);
      expect(Yorum.yagis(25).aktif, -1);
      expect(Yorum.suHava(19, 12).maddeler, isNotEmpty);
      expect(Yorum.uyeAvi(3, 'Lüfer').durum, contains('aktif'));
    });
  });
}
