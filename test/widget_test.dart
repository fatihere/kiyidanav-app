import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/app_state.dart';
import 'package:kiyidanav/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Uygulama açılır ve alt menü görünür', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await appState.load();
    await tester.pumpWidget(const KiyidanAvApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('KıyıdanAv'), findsOneWidget);
    expect(find.text('Keşfet'), findsOneWidget);
    expect(find.text('Sepet'), findsOneWidget);
    // Sepet sekmesi boş durum mesajını gösterir
    await tester.tap(find.text('Sepet'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sepetin boş'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // animasyonları kapat
  });
}
