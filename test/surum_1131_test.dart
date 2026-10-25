import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/badi.dart';
import 'package:kiyidanav/ekran_turu.dart';
import 'package:kiyidanav/notices.dart';

void main() {
  test('mesajda telefon, link, Instagram ve YouTube paylaşılamaz', () {
    expect(mesajDenetle('Yarın sabah Enez\'de buluşalım mı?'), isNull);
    expect(mesajDenetle('Levrek 2,5 kg geldi, 30 m açıkta'), isNull);
    expect(mesajDenetle('beni ara 0532 123 45 67'), contains('telefon'));
    expect(mesajDenetle('+90 (532) 123-45-67'), contains('telefon'));
    expect(mesajDenetle('bak https://ornek.com/x'), contains('link'));
    expect(mesajDenetle('siteye gir ornek.com.tr'), contains('link'));
    expect(mesajDenetle('instagram hesabım var'), contains('Instagram'));
    expect(mesajDenetle('beni ekle @balikci_34'), contains('Instagram'));
    expect(mesajDenetle('youtube kanalıma bak'), contains('YouTube'));
    expect(mesajDenetle('youtu.be/abc'), contains('YouTube'));
    expect(mesajDenetle('25.10.2026 12:30 da Kumkapı'), isNull);
    expect(mesajDenetle('0212 555 44 33'), contains('telefon'));
    expect(mesajDenetle(''), isNull);
  });

  test('yeni takipçi bildirimi telefonun kendi sesiyle gelir', () {
    expect(Notices.toplulukTipi('takip'), isTrue);
  });

  test('mağaza sürümünde ekran turu kapalı', () {
    expect(ekranTuru, isFalse);
  });
}
