// 1.17.1: hava değişimi uyarısı, Kandıra/Sakarya meraları, Kıyıdabiri'nin Uzunkum'u doğru bulması
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/hava_uyari.dart';
import 'package:kiyidanav/kiyidabiri_beyin.dart';
import 'package:kiyidanav/sea.dart';

import 'kiyidabiri_test.dart' show SahteVeri;

class UyeVeri extends SahteVeri {
  @override
  bool get uye => true;
  @override
  List<Spot> denizMeralari() => [...spots];
}

SpotForecast _f(List<HourForecast> h) => SpotForecast(spot: spots.firstWhere((s) => s.name == 'Kefken'), now: const SeaReport(), hours: h);

void main() {
  final t0 = DateTime(2026, 11, 13, 8);
  HourForecast saat(int i, {double w = 10, double g = 14, double dalga = 0.4, double yagis = 0, double p = 1015, int yon = 30}) =>
      HourForecast(time: t0.add(Duration(hours: i)), windKmh: w, gustKmh: g, waveM: dalga, rainMm: yagis, pressure: p, windDir: yon);

  test('sakin havada uyarı yok', () {
    expect(HavaUyari.hesapla(_f([for (var i = 0; i < 24; i++) saat(i)])), isEmpty);
  });

  test('rüzgâr sertleşir, dalga büyür, basınç düşer: saatleriyle uyarılır', () {
    final l = HavaUyari.hesapla(_f([
      for (var i = 0; i < 24; i++)
        saat(i, w: i >= 6 ? 38 : 10, g: i >= 6 ? 50 : 14, dalga: i >= 8 ? 1.6 : 0.4, p: 1016 - i * 0.5, yon: i >= 5 ? 225 : 30),
    ]));
    final turler = l.map((u) => u.tur).toList();
    expect(turler, containsAll(['ruzgar', 'dalga', 'basinc', 'yon']));
    final r = l.firstWhere((u) => u.tur == 'ruzgar');
    expect(r.metin, contains('14:00'));
    expect(r.metin, contains('Lodos'));
  });

  test('fırtına hamlesi tehlike seviyesinde', () {
    final l = HavaUyari.hesapla(_f([for (var i = 0; i < 24; i++) saat(i, w: i >= 3 ? 40 : 12, g: i >= 3 ? 70 : 16)]));
    final f = l.firstWhere((u) => u.tur == 'firtina');
    expect(f.seviye, 2);
    expect(l.any((u) => u.tur == 'ruzgar'), isFalse);
  });

  test('Kandıra–Sakarya meraları listede ve kıyı sırasında', () {
    final ad = spots.map((s) => s.name).toList();
    for (final m in ['Bağırganlı', 'Seyrek', 'Sarısu', 'Kumcağız', 'Cebeci', 'Uzunkum', 'Kocaali']) {
      expect(ad, contains(m));
    }
    expect(ad.indexOf('Ağva') < ad.indexOf('Bağırganlı') && ad.indexOf('Uzunkum') < ad.indexOf('Karasu'), isTrue);
  });

  test('"kandıra uzunkum sahili" → Kandıra\'daki Uzunkum merası (Germencik değil)', () async {
    final y = await KiyidabiriBeyin(UyeVeri()).yanitla('kandıra uzunkum sahili');
    expect(y.metin, contains('Uzunkum'));
    expect(y.metin, isNot(contains('Germencik')));
    expect(y.spot?.name, 'Uzunkum');
  });
}
