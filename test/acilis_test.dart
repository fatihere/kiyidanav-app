import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiyidanav/acilis.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('kimlik 32 karakter onaltılık', () {
    final k = Acilis.yeniKimlik();
    expect(k, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(Acilis.yeniKimlik(), isNot(k));
  });

  test('aynı gün bir kez bildirir, ertesi gün yine bildirir; kimlik sabit kalır', () async {
    final istekler = <Uri>[];
    final c = MockClient((r) async {
      istekler.add(r.url);
      return http.Response('{"ok":true}', 200);
    });
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 15, 9));
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 15, 18));
    expect(istekler.length, 1);
    expect(istekler.first.queryParameters['a'], 'acildi');
    expect(istekler.first.queryParameters['k'], matches(RegExp(r'^[0-9a-f]{32}$')));
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 16, 7));
    expect(istekler.length, 2);
    expect(istekler[1].queryParameters['k'], istekler[0].queryParameters['k']);
  });

  test('sunucu hata verirse gün işaretlenmez, sonra yeniden dener', () async {
    var n = 0;
    final c = MockClient((r) async {
      n++;
      return http.Response('x', n == 1 ? 500 : 200);
    });
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 15));
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 15));
    await Acilis.bildir(istemci: c, simdi: DateTime(2026, 11, 15));
    expect(n, 2);
  });
}
