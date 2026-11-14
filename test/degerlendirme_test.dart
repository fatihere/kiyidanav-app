import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/updates.dart';

void main() {
  test('iPhone App Store yorum sayfasını, Android Play mağazasını açar', () {
    expect(AppUpdate.degerlendirmeAdresi(ios: true).toString(), 'https://apps.apple.com/tr/app/id6824196217?action=write-review');
    final a = AppUpdate.degerlendirmeAdresi(ios: false);
    expect(a.scheme, 'market');
    expect(a.queryParameters['id'], 'com.kiyidanav.kiyidanav');
  });
}
