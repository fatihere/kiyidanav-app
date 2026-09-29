import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/app_state.dart';
import 'package:kiyidanav/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Uygulama açılır, alt menü görünür, sepet boş mesajı çıkar', (tester) async {
    // Gerçek bir telefon ekranı (dar test ekranında yanlış taşma hatası olmasın)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await appState.load();
    await tester.pumpWidget(const KiyidanAvApp());
    await tester.pump(const Duration(milliseconds: 500));

    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    for (final label in ['Keşfet', 'Mera Bilgisi', 'Ara', 'Sepet', 'Hesabım']) {
      expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget, reason: label);
    }

    await tester.tap(find.descendant(of: nav, matching: find.text('Sepet')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sepetin boş'), findsOneWidget);

    // Animasyonları ve bekleyen zamanlayıcıları kapat
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
