// 1.16 → 1.17 tanıtım videosu için ekranlar (gerçek yazı tipleri, sahte deniz verisi). Yalnız elle:
//   EKRAN_GORUNTUSU=1 flutter test test/sunum_ekranlari_test.dart --update-goldens   → test/goldens/sunum/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/badi.dart';
import 'package:kiyidanav/fishkrok.dart';
import 'package:kiyidanav/kiyidabiri.dart';
import 'package:kiyidanav/saatlik_karti.dart';
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kiyidabiri_test.dart' show SahteVeri;

final _acik = Platform.environment['EKRAN_GORUNTUSU'] == '1';

Future<void> _font(String aile, String yol) async {
  final f = File(yol);
  if (!f.existsSync()) return;
  final l = FontLoader(aile)..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  await l.load();
}

Widget _uygulama(Widget ekran) {
  final t = Tide.theme();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: t.copyWith(
        textTheme: t.textTheme.apply(fontFamilyFallback: const ['Emoji']),
        primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: const ['Emoji'])),
    builder: (c, child) => DefaultTextStyle.merge(style: const TextStyle(fontFamilyFallback: ['Emoji']), child: child!),
    home: ekran,
  );
}

Future<void> _boyut(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2280);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

Widget _sohbet() => Scaffold(
      backgroundColor: Colors.black54,
      body: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
              heightFactor: .92,
              child: Material(
                  color: const Color(0xFFF7F5EE),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: KiyidabiriSohbet(veri: SahteVeri())))),
    );

void main() {
  setUpAll(() async {
    await _font('Armata', 'assets/fonts/Armata-Regular.ttf');
    await _font('Lobster', 'assets/fonts/Lobster-Regular.ttf');
    await _font('Emoji', r'C:\Windows\Fonts\seguiemj.ttf');
    await _font('Roboto', r'C:\Windows\Fonts\segoeui.ttf');
    await _font('MaterialIcons', '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\fl\flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  setUp(() => SharedPreferences.setMockInitialValues({'kb_gizlilik_v1': true}));

  Future<void> sohbetAkisi(WidgetTester t, List<(String, String)> adimlar) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(_sohbet()));
    await t.pump(const Duration(milliseconds: 300));
    for (final (yazi, dosya) in adimlar) {
      await t.enterText(find.byType(TextField), yazi);
      await t.tap(find.byIcon(Icons.send));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sunum/$dosya.png'));
    }
  }

  testWidgets('Kıyıdabiri: yer adı, yarın, olta, kargo', (t) async {
    await sohbetAkisi(t, [
      ('Bugün diliskelesindeyim', 's01_dilovasi'),
      ('Kartal yarın nasıl', 's02_yarin'),
    ]);
  }, skip: !_acik);

  testWidgets('Kıyıdabiri: olta ve kargo', (t) async {
    await sohbetAkisi(t, [
      ('LRF', 's03a_lrf'),
      ('bu merada hangi olta ile 19.00 dan sonra av olur', 's03_olta'),
      ('kargo ücreti ne kadar', 's04_kargo'),
    ]);
  }, skip: !_acik);

  testWidgets('Kıyıdabiri: misafire üyelik ekranı', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(const Scaffold(body: SafeArea(child: KiyidabiriSohbet()))));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sunum/s05_misafir.png'));
  }, skip: !_acik);

  testWidgets('Mera Bilgisi: saatlik skor şeridi', (t) async {
    await _boyut(t);
    final kartal = spots.firstWhere((s) => s.name == 'Kartal');
    final bas = DateTime(2026, 11, 12, 0);
    double ruzgar(int i) => [6, 6, 7, 8, 8, 7, 6, 5, 6, 9, 12, 15, 18, 20, 19, 16, 12, 9, 8, 8, 9, 10, 9, 8][i % 24].toDouble();
    final f = SpotForecast(
      spot: kartal,
      now: const SeaReport(windKmh: 8, waveM: 0.3, seaC: 16),
      days: [
        for (var g = 0; g < 3; g++)
          DayForecast(date: DateTime(2026, 11, 12 + g), sunrise: DateTime(2026, 11, 12 + g, 7, 2), sunset: DateTime(2026, 11, 12 + g, 16, 51)),
      ],
      hours: [
        for (var i = 0; i < 72; i++)
          HourForecast(
              time: bas.add(Duration(hours: i)),
              windKmh: ruzgar(i) + (i >= 24 ? 6 : 0),
              waveM: 0.2 + ruzgar(i) / 40,
              seaC: 16.4,
              pressureTrend: i < 30 ? -1.8 : 0.5),
      ],
    );
    await t.pumpWidget(_uygulama(Scaffold(
      appBar: AppBar(title: const Text('Günlük Mera Balık Bilgisi')),
      body: ListView(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(22)),
          child: const Text('Kartal · Anadolu Yakası\nPerşembe — av verimliliği %78',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        ),
        SaatlikSkorKarti(f: f, simdi: DateTime(2026, 11, 12, 0)),
      ]),
    )));
    await t.pump(const Duration(milliseconds: 300));
    if (find.text('18').evaluate().isNotEmpty) await t.tap(find.text('18').first, warnIfMissed: false);
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sunum/s06_saatlik.png'));
  }, skip: !_acik);

  testWidgets('KıyıdanPaylaş ve Badimi bul giriş kartları', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(Scaffold(
      backgroundColor: const Color(0xFFF6F4EE),
      body: SafeArea(
        child: ListView(children: [
          FishkrokGirisKarti(onTap: () {}),
          const BadiGirisKarti(),
        ]),
      ),
    )));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sunum/s07_paylas_badi_kartlari.png'));
  }, skip: !_acik);
}
