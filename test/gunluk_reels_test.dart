// "Bugün balık kaç metrede?" — günlük Instagram Reels üreticisi (9 Kasım 2026)
// Uygulamanın KENDİ hesabıyla günün illerindeki meraları o anki gerçek veriyle hesaplar (gunluk_reels/veri.dart),
// 15.11.2026: il planı — test/gunluk_reels/plan.json'daki günler elle (ör. İstanbul 3 + Kocaeli 3), diğer günler
// meraları olan kıyı illerinden tarihe bağlı rastgele 3 farklı il (her ilden 1 mera).
// 1080x1920 kareleri veriden üretilen canlı sahnelerle çizer (gunluk_reels/cizim.dart). MP4: tool/gunluk_reels.sh
//   GUNLUK_REELS=1 flutter test test/gunluk_reels_test.dart
// Ortam: GUNLUK_REELS_CIKTI (çıktı klasörü), GUNLUK_REELS_FONT (yazı tipleri), GUNLUK_REELS_TEMA (safak|turkuaz|altin|gece|firtina),
//        GUNLUK_REELS_ORNEK=1 (yalnız her 15. kare)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/api.dart';
import 'package:kiyidanav/kiyilama.dart';
import 'package:kiyidanav/sea.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gunluk_reels/cizim.dart';
import 'gunluk_reels/figurler.dart';
import 'gunluk_reels/veri.dart';

final _acik = Platform.environment['GUNLUK_REELS'] == '1';
const _fps = 30;

Future<void> _font(String aile, String yol) async {
  final f = File(yol);
  if (!f.existsSync()) {
    // ignore: avoid_print
    print('yazı tipi yok: $yol');
    return;
  }
  await (FontLoader(aile)..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)))).load();
}


String aciklama(List<MeraGunu> uc, DateTime now) {
  final b = StringBuffer('🎣 Bugün balık kaç metrede? ${kucukHarf(gunAdi(now))}\n\n');
  for (var i = 0; i < uc.length; i++) {
    final m = uc[i];
    b.writeln('${i + 1}) ${m.spot.name}${m.il.isNotEmpty ? ' (${m.il})' : ''}: büyük balık ${m.firtina ? "bugün yok, kıyıdan uzak dur" : m.k.buyuk}, '
        'küçük balık ${m.k.kucuk} · ${m.k.takim} · rüzgâr ${m.r.effectiveWind.round()} km/s ${kucukHarf(m.r.windFrom)}'
        '${m.spot.strait ? "" : ", dalga ${ondalik(m.r.effectiveWave)} m"}');
  }
  b.writeln('\n📲 Senin meranda balık bugün kaç metrede? Rüzgâr, dalga, mesafe ve takım önerisi KıyıdanAv uygulamasında, '
      'Türkiye kıyıları için canlı. Ücretsiz indir: link profilde 👆');
  b.writeln('✅ Balık kaç metrede  ✅ Canlı mera raporu  ✅ Kıyıdabiri asistanı  (Google Play · App Store)');
  final etiket = {for (final m in uc) if (m.il.isNotEmpty) '#${kucukHarfTr(m.il).replaceAll(' ', '')}'};
  b.write('\n#balıkavı ${etiket.isEmpty ? '#istanbul' : etiket.join(' ')} #kıyıdanav #levrek #lüfer #spin #lrf #surfcasting #balıkçılık #olta #balıkçılıkuygulaması');
  return b.toString();
}

void main() {
  testWidgets('günlük Reels kareleri', (t) async {
    final cikti = Directory(Platform.environment['GUNLUK_REELS_CIKTI'] ?? 'build/gunluk_reels')..createSync(recursive: true);
    final fd = Platform.environment['GUNLUK_REELS_FONT'] ?? r'C:\fl\tmp\fonts';
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\fl\flutter';
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null; // gerçek ağ

    final hazir = await t.runAsync(() async {
      await _font(fBas, '$fd/BarlowCondensed-ExtraBold.ttf');
      await _font(fBasB, '$fd/BarlowCondensed-Bold.ttf');
      await _font(fGov, '$fd/Barlow-SemiBold.ttf');
      await _font(fGovM, '$fd/Barlow-Medium.ttf');
      await _font('Armata', 'assets/fonts/Armata-Regular.ttf');
      await _font('Emoji', Platform.isWindows ? r'C:\Windows\Fonts\seguiemj.ttf' : '$fd/NotoColorEmoji.ttf');
      await _font('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      final kod = await ui.instantiateImageCodec(File('assets/brand/kiyidabiri.png').readAsBytesSync(), targetWidth: 400);
      final robot = (await kod.getNextFrame()).image;
      await Api.loadConfig();
      final now = DateTime.now();
      final harita = IlHaritasi.dosyadan();
      // her meranın ili (kullanıcıya açık meralar)
      final ilMeralari = <String, List<Spot>>{};
      for (final s in spots.where((s) => !s.custom)) {
        final il = harita.meraIli(s);
        if (il.isNotEmpty) (ilMeralari[il] ??= []).add(s);
      }
      final plan = gunPlani(now, ilMeralari.keys);
      // ignore: avoid_print
      print('gün planı: $plan');
      final secilen = <MeraGunu>[];
      final hepsi = <MeraGunu>[];
      for (final (i, (il, adet)) in plan.indexed) {
        final aday = [...?ilMeralari[il]]..shuffle(Random(now.year * 1000 + now.month * 50 + now.day + i));
        final l = <MeraGunu>[];
        for (final s in aday.take(math.max(8, adet * 3))) {
          final m = await meraGunu(s, now, il: il);
          if (m != null) l.add(m);
        }
        hepsi.addAll(l);
        secilen.addAll(secim(l, now, adet: adet, tohum: i));
      }
      // tek mera/il planında en iyi puanlı başa; il grupları (İstanbul 3 + Kocaeli 3) plan sırasında kalır
      if (plan.every((p) => p.$2 == 1)) secilen.sort((a, b) => b.puan.compareTo(a.puan));
      File('${cikti.path}/veri.json').writeAsStringSync(const JsonEncoder.withIndent(' ')
          .convert({'zaman': now.toIso8601String(), 'plan': [for (final p in plan) [p.$1, p.$2]], 'meralar': hepsi.map((e) => e.json()).toList()}));
      return (secilen, Kaynaklar(harita.tumHalkalar, robot));
    });
    final (secilen, kn) = hazir!;
    expect(secilen.length, greaterThanOrEqualTo(3), reason: 'yeterli mera verisi gelmedi');
    final now = DateTime.now();
    final tm = Tema.sec(secilen, now, Platform.environment['GUNLUK_REELS_TEMA']);
    File('${cikti.path}/aciklama.txt').writeAsStringSync(aciklama(secilen, now));
    File('${cikti.path}/secilen.json').writeAsStringSync(jsonEncode({'tema': tm.ad, 'meralar': secilen.map((e) => e.json()).toList()}));

    final S = sahneler(secilen, now, tm, kn);
    final toplam = S.fold<double>(0, (s, e) => s + e.sure);
    t.view.physicalSize = const Size(rw, rh);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final anahtar = GlobalKey();
    final yalnizOrnek = Platform.environment['GUNLUK_REELS_ORNEK'] == '1';
    for (var n = 0; n < (toplam * _fps).round(); n++) {
      if (yalnizOrnek && n % 15 != 0) continue;
      await t.pumpWidget(RepaintBoundary(key: anahtar, child: kare(S, n / _fps)));
      final bytes = await t.runAsync(() async {
        final ro = anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        return bd!.buffer.asUint8List();
      });
      File('${cikti.path}/kare_${n.toString().padLeft(4, '0')}.png').writeAsBytesSync(bytes!);
    }
    File('${cikti.path}/sure.txt').writeAsStringSync(toplam.toStringAsFixed(2));
  }, skip: !_acik, timeout: const Timeout(Duration(minutes: 20)));

  test('il planı: meraların ili, 16 Kasım İstanbul 3 + Kocaeli 3, diğer günler 3 farklı il', () {
    final h = IlHaritasi.dosyadan();
    final ilMeralari = <String, List<Spot>>{};
    for (final s in spots) {
      final il = h.meraIli(s);
      expect(il, isNotEmpty, reason: '${s.name} için il bulunamadı');
      (ilMeralari[il] ??= []).add(s);
    }
    String ilOf(String ad) => h.meraIli(spots.firstWhere((s) => s.name == ad));
    expect(ilOf('Uzunkum'), 'Kocaeli');
    expect(ilOf('Kocaali'), 'Sakarya');
    expect(ilOf('Tuzla'), 'İstanbul');
    expect(ilOf('Hersek'), 'Yalova');
    expect(ilOf('Gölcük'), 'Kocaeli');
    expect(ilMeralari['İstanbul']!.length, greaterThanOrEqualTo(6));
    expect(ilMeralari['Kocaeli']!.length, greaterThanOrEqualTo(6));
    expect(gunPlani(DateTime(2026, 11, 16), ilMeralari.keys), [('İstanbul', 3), ('Kocaeli', 3)]);
    final gunler = <String>{};
    for (var g = 15; g < 30; g++) {
      if (g == 16) continue;
      final p = gunPlani(DateTime(2026, 11, g), ilMeralari.keys);
      expect(p.length, 3);
      expect(p.map((e) => e.$1).toSet().length, 3);
      gunler.add(p.map((e) => e.$1).join(','));
    }
    expect(gunler.length, greaterThanOrEqualTo(12));
    // ignore: avoid_print
    print('iller: ${ilMeralari.map((k, v) => MapEntry(k, v.length))} · 15 Kasım: ${gunPlani(DateTime(2026, 11, 15), ilMeralari.keys)} · 17 Kasım: ${gunPlani(DateTime(2026, 11, 17), ilMeralari.keys)}');
  });

  test('mera seçimi her gün farklı, aynı gün aynı', () {
    final l = [
      for (final (i, sp) in [...spotsOf(Side.anadolu), ...spotsOf(Side.avrupa)].indexed)
        MeraGunu(sp, SpotForecast(spot: sp, now: SeaReport(windKmh: 8 + (i % 5) * 2.0, waveM: 0.3, windDir: 45)), 60 + (i * 7) % 35,
            kiyilamaHesapla(profil: const []), '', null, const ['Levrek']),
    ];
    String ad(List<MeraGunu> s) => s.map((m) => m.spot.name).join(',');
    final gunler = [for (var g = 0; g < 7; g++) ad(secim(l, DateTime(2026, 11, 9 + g)))];
    expect(ad(secim(l, DateTime(2026, 11, 9))), gunler.first); // aynı gün → aynı seçim
    expect(gunler.toSet().length, greaterThanOrEqualTo(5)); // bir haftada en az 5 farklı üçlü
    for (var g = 0; g < 7; g++) {
      final s = secim(l, DateTime(2026, 11, 9 + g));
      expect(s.length, 3);
      expect(s.where((m) => m.spot.side == Side.anadolu).length, lessThanOrEqualTo(2));
      expect(s.where((m) => m.spot.side == Side.avrupa).length, lessThanOrEqualTo(2));
    }
    // ignore: avoid_print
    print(gunler.join(' | '));
  });

  // Tür örnek sayfası (tasarım kontrolü): GUNLUK_REELS_TURLER=1
  testWidgets('balık türleri sayfası', (t) async {
    final fd = Platform.environment['GUNLUK_REELS_FONT'] ?? r'C:l	mponts';
    await t.runAsync(() => _font(fBasB, '$fd/BarlowCondensed-Bold.ttf'));
    t.view.physicalSize = const Size(1080, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final k = GlobalKey();
    const l = [TurStil.levrek, TurStil.lufer, TurStil.cipura, TurStil.karagoz, TurStil.kefal, TurStil.palamut, TurStil.istavrit];
    await t.pumpWidget(RepaintBoundary(
        key: k,
        child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(size: const Size(1080, 1100), painter: _TurSayfasi(l)))));
    final b = await t.runAsync(() async {
      final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    File('build/turler.png').writeAsBytesSync(b!);
  }, skip: Platform.environment['GUNLUK_REELS_TURLER'] != '1');
}

class _TurSayfasi extends CustomPainter {
  final List<TurStil> l;
  _TurSayfasi(this.l);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0B3A5C));
    for (var i = 0; i < l.length; i++) {
      final o = Offset(i.isEven ? 280 : 800, 130 + i * 140.0);
      turCiz(c, o, 380, l[i], t: i * 0.3, hale: const Color(0xFF5CFFC9));
      final tp = TextPainter(text: TextSpan(text: l[i].ad, style: ts(fBasB, 40, Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(o.dx - tp.width / 2, o.dy + 60));
    }
  }

  @override
  bool shouldRepaint(_TurSayfasi o) => false;
}
