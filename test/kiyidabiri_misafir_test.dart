// 1.16.0: Kıyıdabiri yalnızca üyelere özel — misafir sohbet yerine üyelik ekranını görür
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/kiyidabiri.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('misafire üye ol / giriş yap gösterilir, yazma alanı yok', (t) async {
    SharedPreferences.setMockInitialValues({'kb_gizlilik_v1': true});
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: KiyidabiriSohbet())));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Kıyıdabiri yalnızca üyelere özel'), findsOneWidget);
    expect(find.text('Ücretsiz üye ol'), findsOneWidget);
    expect(find.text('Üyeyim, giriş yap'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
