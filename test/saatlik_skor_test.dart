// 1.17.0: saatlik av skoru, en iyi pencereler, türe göre skor ve av kayıtlarından skor ayarı
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/saatlik_skor.dart';
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/solunar.dart';

SpotForecast _tahmin({double ruzgar = 8, double dalga = 0.4, double Function(int saat)? ruzgarSaat}) {
  final kartal = spots.firstWhere((s) => s.name == 'Kartal');
  final bas = DateTime(2026, 11, 12, 0);
  return SpotForecast(
    spot: kartal,
    now: const SeaReport(),
    days: [
      for (var g = 0; g < 3; g++)
        DayForecast(
            date: DateTime(2026, 11, 12 + g),
            sunrise: DateTime(2026, 11, 12 + g, 7, 0),
            sunset: DateTime(2026, 11, 12 + g, 16, 50)),
    ],
    hours: [
      for (var i = 0; i < 72; i++)
        HourForecast(
            time: bas.add(Duration(hours: i)),
            windKmh: ruzgarSaat?.call(i) ?? ruzgar,
            waveM: dalga,
            seaC: 16,
            pressureTrend: 0),
    ],
  );
}

void main() {
  setUp(SkorAyar.sifirla);

  test('şafak ve akşam saatleri gece yarısından yüksek; pencere 00–04 arasında önerilmez', () {
    final f = _tahmin();
    final l = SaatlikSkor.gun(SaatlikSkor.hepsi(f), 0, simdi: DateTime(2026, 11, 12, 0));
    expect(l.length, 24);
    int skor(int h) => l.firstWhere((x) => x.time.hour == h).skor;
    expect(skor(7), greaterThan(skor(2)));
    expect(skor(17), greaterThan(skor(13)));
    expect(l.firstWhere((x) => x.time.hour == 7).dilim, Dilim.safak);
    final p = SaatlikSkor.enIyiPencereler(l);
    expect(p.length, 2);
    for (final x in p) {
      expect(x.bas.hour, greaterThanOrEqualTo(4));
      expect(x.bit.difference(x.bas).inHours, 2);
    }
    // çakışmazlar
    expect(p[0].bit.isAfter(p[1].bas), isFalse);
  });

  test('fırtınalı saat skoru düşer; yarın ve öbür gün ayrı seçilir', () {
    final f = _tahmin(ruzgarSaat: (i) => i >= 24 + 6 && i <= 24 + 10 ? 45 : 8);
    final hepsi = SaatlikSkor.hepsi(f);
    final yarin = SaatlikSkor.gun(hepsi, 1, simdi: DateTime(2026, 11, 12, 0));
    expect(yarin.first.time.day, 13);
    final firtina = yarin.firstWhere((x) => x.time.hour == 7).skor;
    final sakin = SaatlikSkor.gun(hepsi, 2, simdi: DateTime(2026, 11, 12, 0)).firstWhere((x) => x.time.hour == 7).skor;
    expect(firtina, lessThan(sakin - 15));
  });

  test('Kartal, Kasım: en olası türler bölgenin türleri, yasaklı tür yok', () {
    final f = _tahmin();
    final l = SaatlikSkor.gun(SaatlikSkor.hepsi(f), 0, simdi: DateTime(2026, 11, 12, 0));
    final t = turSkorlari(f.spot, l, zaman: DateTime(2026, 11, 12, 12));
    expect(t.length, 3);
    for (final x in t) {
      expect(['istavrit', 'lufer', 'kefal', 'palamut', 'levrek', 'mezgit', 'zargana', 'kolyoz', 'izmarit', 'iskorpit',
          'barbunya', 'kirlangic'], contains(x.tur));
      expect(x.skor, inInclusiveRange(5, 98));
      expect(x.pencere, isNotNull);
    }
    // Kartal'da çipura yok
    expect(t.map((x) => x.tur), isNot(contains('cupra')));
  });

  test('av kayıtlarından gelen düzeltme skora yansır (±8 sınırı)', () {
    final once = FishingScore.compute(DateTime(2026, 11, 12, 12), windKmh: 25, waveM: 0.5);
    SkorAyar.yukleJson({
      'n': 52,
      'ayar': {
        'ruzgar': {'20-30': 40}, // 8'e kırpılır
        'saat': {'aksam': 3},
      }
    });
    expect(FishingScore.compute(DateTime(2026, 11, 12, 12), windKmh: 25, waveM: 0.5), once + 8);
    expect(SkorAyar.ornek, 52);
    expect(SkorAyar.saat('aksam'), 3);
  });

  test('solunar dönem 0/1/2 döner ve günde en az bir büyük dönem vardır', () {
    var buyuk = 0;
    for (var h = 0; h < 24; h++) {
      final d = solunarDonem(DateTime(2026, 11, 12, h), 29.2);
      expect([0, 1, 2], contains(d));
      if (d == 2) buyuk++;
    }
    expect(buyuk, greaterThanOrEqualTo(2));
  });
}
