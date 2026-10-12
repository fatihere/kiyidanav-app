import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/share.dart';
import 'package:kiyidanav/share_card.dart';

void main() {
  test('rapor görseli ~1080 px genişlikte üretilir (1,5x – 3x)', () {
    expect(Sharer.imagePixelRatio(360, 1080), 3.0);
    expect(Sharer.imagePixelRatio(400, 1080), closeTo(2.7, 0.001));
    expect(Sharer.imagePixelRatio(1000, 1080), 1.5);
    expect(Sharer.imagePixelRatio(0, 1080), 2.5);
  });

  testWidgets('paylaşım kartı 1080×1350 PNG olarak çizilir', (tester) async {
    final bytes = await tester.runAsync(() => ShareCard.render(
          const ShareCardData(
            place: 'Riva · Anadolu',
            date: '13 Ekim 2026 · Salı',
            score: 72,
            scoreLabel: 'İyi',
            moonName: 'Son Dördün',
            moonPct: 48,
            verdict: 'Kıyıdan av için uygun',
            chips: [
              (Icons.air, 'Rüzgâr', '12 km/s KD'),
              (Icons.waves, 'Dalga', '0.6 m'),
              (Icons.thermostat, 'Su / Hava', '19° / 17°'),
            ],
            morning: '06:10 – 08:10',
            evening: '17:40 – 19:40',
            days: [('Sal', 72, Icons.wb_sunny, Colors.amber), ('Çar', 55, Icons.cloud, Colors.white)],
          ),
          withLogo: false,
        ));
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]); // "PNG"
  });
}
