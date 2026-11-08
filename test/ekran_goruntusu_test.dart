// 1.14.0 ekran görüntüleri (gerçek yazı tipleriyle, sahte deniz verisiyle). Yalnız elle çalıştırılır:
//   flutter test test/ekran_goruntusu_test.dart --update-goldens (ortam değişkeni EKRAN_GORUNTUSU=1)
// Çıktı: test/goldens/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/av_gunu.dart';
import 'package:kiyidanav/kiyidabiri.dart';
import 'package:kiyidanav/locate.dart';
import 'package:kiyidanav/mera_oner.dart';
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/sea_card.dart';
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

void main() {
  setUpAll(() async {
    await _font('Armata', 'assets/fonts/Armata-Regular.ttf');
    await _font('Emoji', r'C:\Windows\Fonts\seguiemj.ttf');
    await _font('Roboto', r'C:\Windows\Fonts\segoeui.ttf');
    await _font('MaterialIcons', '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\fl\flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'kb_gizlilik_v1': false});
  });

  testWidgets('01 Kıyıdabiri sohbet akışı', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(Scaffold(
      backgroundColor: Colors.black54,
      body: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(heightFactor: .92, child: Material(
            color: const Color(0xFFF7F5EE),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: KiyidabiriSohbet(veri: SahteVeri())))),
    )));
    await t.pump(const Duration(milliseconds: 300));
    Future<void> yaz(String s) async {
      await t.enterText(find.byType(TextField), s);
      await t.tap(find.byIcon(Icons.send));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/01_kiyidabiri_karsilama.png'));
    await yaz('Bugün kartaldayım');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/02_kiyidabiri_mera_ozeti.png'));
    await yaz('Surf');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/03_kiyidabiri_stil_onerisi.png'));
    await yaz('Olta makinesi');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/04_kiyidabiri_kampanya.png'));
    await yaz('uzaya roket ile balık tutulur mu');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/05_kiyidabiri_temsilci.png'));
  }, skip: !_acik);

  testWidgets('06 Robot ana ekranda (alt menünün üstünde, karşılama balonu)', (t) async {
    await _boyut(t);
    await KiyidabiriAyar.yukle();
    await KiyidabiriAyar.sesAyarla(false);
    await t.pumpWidget(_uygulama(Scaffold(
      appBar: AppBar(title: const Text('KıyıdanAv')),
      body: KiyidabiriKatmani(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < 4; i++)
          Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: i == 0 ? Tide.derin : Colors.white, borderRadius: BorderRadius.circular(18))),
      ])),
      bottomNavigationBar: NavigationBar(destinations: const [
        NavigationDestination(icon: Icon(Icons.explore), label: 'Keşfet'),
        NavigationDestination(icon: Icon(Icons.set_meal_outlined), label: 'Mera Bilgisi'),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Paylaş'),
        NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Sepet'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Hesabım'),
      ]),
    )));
    await t.pump(const Duration(milliseconds: 1800));
    await t.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/06_robot_ana_ekran.png'));
  }, skip: !_acik);

  testWidgets('07 Nokta meran rozeti (konum şeridi)', (t) async {
    await _boyut(t);
    selectedSpot.value = Spot.pin(41.18, 29.09, spots.firstWhere((s) => s.name == 'Beykoz'), ad: 'Anadolu Kavağı, Beykoz');
    await t.pumpWidget(_uygulama(const Scaffold(
        body: SafeArea(child: Column(children: [SizedBox(height: 20), LocationBar(), SizedBox(height: 10), Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [Text('Deniz kartında: '), NoktaRozeti()]),
        )])))));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/07_nokta_meran.png'));
  }, skip: !_acik);

  testWidgets('08 Mera öner formu', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(const MeraOnerFormu(tur: MeraTuru.tuzlu, token: 'x')));
    await t.pump();
    await t.enterText(find.byType(TextField).first, 'Kireçburnu mendireği');
    await t.tap(find.text('Levrek'));
    await t.tap(find.text('Spin'));
    await t.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/08_mera_oner_formu.png'));
    await t.drag(find.byType(ListView), const Offset(0, -1500));
    await t.pump();
    await t.tap(find.byType(Checkbox));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/09_mera_oner_isim_izni.png'));
  }, skip: !_acik);

  testWidgets('10 Topluluk meraları', (t) async {
    await _boyut(t);
    MeraOnerApi.onaylilar.value = const [
      MeraOnerisi(
          id: 1,
          tur: MeraTuru.tuzlu,
          ad: 'Kireçburnu mendireği',
          lat: 41.147,
          lon: 29.056,
          il: 'İstanbul',
          ilce: 'Sarıyer',
          baliklar: ['Levrek', 'Lüfer / Çinekop', 'İstavrit'],
          teknikler: ['Spin', 'LRF'],
          dip: 'Kaya, Mendirek / taş dolgu',
          derinlik: '30 m açıkta 7–9 m',
          zaman: 'Sabah, Akşam',
          notlar: 'Poyrazda akıntı mendireğin ucunda döner; akşamüstü köpük hattına sahte at.',
          oneren: 'Fatih Eren'),
      MeraOnerisi(id: 2, tur: MeraTuru.tuzlu, ad: 'Garipçe kayalıkları', lat: 41.21, lon: 29.11, baliklar: ['Sargoz', 'Karagöz'], teknikler: ['LRF']),
    ];
    await t.pumpWidget(_uygulama(const MeraOnerileriEkrani()));
    await t.pump();
    MeraOnerApi.onaylilar.notifyListeners();
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/10_topluluk_meralari.png'));
  }, skip: !_acik);

  testWidgets('11 Çinekop: mantarlı takım çizimi ve tekne sorusu', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(Scaffold(
      body: SafeArea(
          child: Material(
              color: const Color(0xFFF7F5EE), child: KiyidabiriSohbet(veri: SahteVeri()))),
    )));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField), 'yemli çinekop avı nasıl yapılır');
    await t.tap(find.byIcon(Icons.send));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.drag(find.byType(ListView), const Offset(0, 900));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/11_cinekop_mantarli_takim.png'));
    await t.drag(find.byType(ListView), const Offset(0, -3000));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/12_cinekop_tekne_sorusu.png'));
  }, skip: !_acik);

  testWidgets('13 Mera Bilgisi: Mera öner kartı', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(const Scaffold(body: SafeArea(child: Column(children: [MeraOnerGirisKarti()])))));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/13_mera_oner_karti.png'));
  }, skip: !_acik);

  testWidgets('14 Kıyıdabiri ekipman ve kampanya', (t) async {
    await _boyut(t);
    await t.pumpWidget(_uygulama(Scaffold(
      body: SafeArea(child: Material(color: const Color(0xFFF7F5EE), child: KiyidabiriSohbet(veri: SahteVeri()))),
    )));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/14_kiyidabiri_karsilama_yeni.png'));
    Future<void> yaz(String m) async {
      await t.enterText(find.byType(TextField), m);
      await t.tap(find.byIcon(Icons.send));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    await yaz('levrek için hangi makine alayım');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/15_kiyidabiri_ekipman.png'));
    await yaz('kampanyalar');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/16_kiyidabiri_kampanyalar.png'));
  }, skip: !_acik);

  testWidgets('17 Av günüm kartı', (t) async {
    await _boyut(t);
    final kartal = spots.firstWhere((s) => s.name == 'Kartal');
    await AvGunleri.ekle(AvGunu.gunden(kartal, GunHava(DateTime(2026, 11, 4), ruzgar: 14, hamle: 18, yon: 30, dalga: 0.5, su: 17),
        not: '3 levrek, akşamüstü kaşık'));
    final f = SpotForecast(spot: kartal, now: const SeaReport(windKmh: 12, gustKmh: 18, windDir: 40, waveM: 0.4, seaC: 17), days: [
      DayForecast(date: DateTime(2026, 11, 8), windMax: 12, gustMax: 18, waveMax: 0.4, windDir: 40),
    ]);
    await t.pumpWidget(_uygulama(Scaffold(body: SafeArea(child: ListView(children: [AvGunuKarti(f: f)])))));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/17_av_gunum.png'));
  }, skip: !_acik);

  test('Locate yüklü', () => expect(Locate.nearest(41, 29).$1, isNotNull));
}
