import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/saatlik_karti.dart';
import 'package:kiyidanav/sea.dart';

void main() {
  testWidgets('Saatlik skor kartı 360 px ekranda taşmadan çizilir; gün ve çubuk seçimi çalışır', (t) async {
    t.view.physicalSize = const Size(360, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final kartal = spots.firstWhere((s) => s.name == 'Kartal');
    final bas = DateTime(2026, 11, 12, 0);
    final f = SpotForecast(
      spot: kartal,
      now: const SeaReport(),
      days: [for (var g = 0; g < 3; g++) DayForecast(date: DateTime(2026, 11, 12 + g), sunrise: DateTime(2026, 11, 12 + g, 7), sunset: DateTime(2026, 11, 12 + g, 16, 50))],
      hours: [for (var i = 0; i < 72; i++) HourForecast(time: bas.add(Duration(hours: i)), windKmh: 6.0 + i % 20, waveM: 0.4, seaC: 16)],
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [SaatlikSkorKarti(f: f, simdi: DateTime(2026, 11, 12, 0))]))));
    expect(find.text('Saatlik av skoru'), findsOneWidget);
    expect(find.textContaining('En iyi saatler'), findsOneWidget);
    expect(find.textContaining('en olası türler'), findsOneWidget);
    await t.tap(find.text('Yarın'));
    await t.pump();
    expect(find.text('Yarın en olası türler'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
