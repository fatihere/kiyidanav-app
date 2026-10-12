import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/app_state.dart';
import 'package:kiyidanav/freshwater.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/screens/freshwater_screen.dart';

Map<String, dynamic> _json(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

void main() {
  final raw = _json('assets/data/tatli_su.json');
  final data = FwData.fromJson(raw);
  final shapes = FwMapShapes.fromJson(_json('assets/data/tr_harita.json'));

  group('Tatlı su verisi', () {
    test('tüm yerler okunur, kimlikler tekil, koordinatlar Türkiye içinde', () {
      final rawCount = (raw['yerler'] as List).length;
      expect(data.places.length, rawCount, reason: 'Türkiye dışı koordinat olmamalı');
      expect(data.places.length, greaterThanOrEqualTo(40));
      expect(data.places.map((p) => p.id).toSet().length, data.places.length);
      for (final p in data.places) {
        expect(p.province, isNotEmpty, reason: p.id);
        expect(p.district, isNotEmpty, reason: p.id);
        expect(p.fish, isNotEmpty, reason: p.id);
      }
    });

    test('her balığın rehberi, yöntemi ve ekipmanı var', () {
      for (final p in data.places) {
        for (final k in p.fish) {
          final f = data.fish[k];
          expect(f, isNotNull, reason: '${p.id}: $k');
          expect(f!.methods, isNotEmpty, reason: k);
          expect(f.gear, isNotEmpty, reason: k);
        }
      }
      final sapanca = data.places.firstWhere((p) => p.id == 'sapanca');
      final gear = data.gearFor(sapanca);
      expect(gear.map((g) => g.query).toSet().length, gear.length, reason: 'ekipman tekrarsız');
    });

    test('liste il sırasına göre (Türkçe alfabe)', () {
      for (var i = 1; i < data.places.length; i++) {
        expect(trCompare(data.places[i - 1].province, data.places[i].province), lessThanOrEqualTo(0));
      }
      expect(trCompare('Çorum', 'Denizli'), lessThan(0));
      expect(trCompare('Isparta', 'İzmir'), lessThan(0));
      expect(trCompare('Şanlıurfa', 'Tokat'), lessThan(0));
      expect(trUpper('Kırşehir'), 'KIRŞEHİR');
      expect(trLower('İZNİK ISPARTA'), 'iznik ısparta');
    });

    test('içme suyu barajları "av yasak" olarak işaretli', () {
      expect(data.places.firstWhere((p) => p.id == 'omerli').noFishing, isTrue);
      expect(data.places.firstWhere((p) => p.id == 'iznik').noFishing, isFalse);
    });

    test('harita: 81 il ve göl alanları', () {
      expect(shapes.provinces.length, 81);
      expect(shapes.water, isNotEmpty);
      const s = Size(400, 200);
      final o = FwProjection.project(29.0, 41.0, s);
      expect(o.dx, inInclusiveRange(0, 400));
      expect(o.dy, inInclusiveRange(0, 200));
    });

    test('panel anahtarı (tatli_su) yoksa açık, false ise kapalı', () {
      expect(const Features().freshwater, isTrue);
      expect(Features.fromJson({'tatli_su': false}).freshwater, isFalse);
    });
  });

  testWidgets('Tatlı su ekranı ve detay sayfası açılır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    memberNotifier.value = true;
    addTearDown(() => memberNotifier.value = false);

    await tester.runAsync(() async {
      await FreshwaterService.load();
      await FreshwaterService.loadMap();
    });
    await tester.pumpWidget(const MaterialApp(home: FreshwaterScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tatlı Su Meraları'), findsOneWidget);
    expect(find.text('Göller'), findsOneWidget);

    // Arama: "sapanca"
    await tester.enterText(find.byType(TextField), 'sapanca');
    await tester.pump();
    expect(find.text('Sapanca Gölü'), findsOneWidget);

    await tester.tap(find.text('Sapanca Gölü'));
    await tester.pumpAndSettle();
    expect(find.text('Araçla ulaşım'), findsOneWidget);
    expect(find.text('Yol tarifi al'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Giriş kartı başlığı', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FreshwaterEntry())));
    expect(find.text('Tatlı Su Meraları ve Avlanma Yöntemleri'), findsOneWidget);
  });
}
