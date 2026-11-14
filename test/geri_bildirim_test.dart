import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiyidanav/geri_bildirim.dart';

void main() {
  test('gönderim: üye anahtarı, puan ve metin gider; yeni kupon okunur', () async {
    late http.Request giden;
    final c = MockClient((r) async {
      giden = r;
      return http.Response(
          jsonEncode({'ok': true, 'yeni': true, 'kupon': {'kod': 'GBAB12CD34', 'oran': 5, 'son': '2027-02-13', 'kullanildi': false}}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final (hata, kupon, yeni) = await GeriBildirimApi.gonder('anahtar', 4, 'Mera bilgisi çok iyi', 'Daha fazla mera', c: c);
    expect(hata, isNull);
    expect(yeni, isTrue);
    expect(kupon!.kod, 'GBAB12CD34');
    expect(kupon.sonTarih, '13.02.2027');
    expect(giden.headers['X-Av-Anahtar'], 'anahtar');
    expect(giden.url.queryParameters['a'], 'gonder');
    final b = jsonDecode(giden.body) as Map;
    expect(b['puan'], 4);
    expect(b['eksik'], 'Daha fazla mera');
  });

  test('sunucu hatası metni kullanıcıya iletilir; eski kupon korunur', () async {
    final c = MockClient((r) async => http.Response(
        jsonEncode({'ok': false, 'error': 'Geri bildirimin az önce alındı, teşekkürler.', 'kupon': {'kod': 'GBX', 'oran': 5}}), 429, headers: {'content-type': 'application/json; charset=utf-8'}));
    final (hata, kupon, yeni) = await GeriBildirimApi.gonder('a', 5, 'xxxxxxxxxxxxxxxx', '', c: c);
    expect(hata, contains('az önce'));
    expect(kupon!.kod, 'GBX');
    expect(yeni, isFalse);
  });

  test('durum: daha önce alınan kupon ve oran', () async {
    final c = MockClient((r) async => http.Response(jsonEncode({'ok': true, 'kupon_acik': true, 'oran': 7, 'kupon': null}), 200));
    final (acik, oran, kupon) = await GeriBildirimApi.durum('a', c: c);
    expect(acik, isTrue);
    expect(oran, 7);
    expect(kupon, isNull);
  });

  testWidgets('üye değilse giriş yapma mesajı', (t) async {
    await t.pumpWidget(const MaterialApp(home: GeriBildirimEkrani()));
    await t.pumpAndSettle();
    expect(find.textContaining('üye girişi yap'), findsOneWidget);
  });
}
