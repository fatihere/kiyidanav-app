import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/fishkrok.dart';
import 'package:kiyidanav/fk_bildirim.dart';

void main() {
  test('beğeni bildirimi başlığı Instagram adını kullanır', () {
    final e = FkEtkilesim.fromJson({'id': 3, 'tur': 'begeni', 'av_id': 'a1', 'ad': 'Mert E.', 'instagram': 'mrtengiin', 'balik': 'Uskumru'});
    expect(e.baslik, '@mrtengiin Uskumru avını beğendi');
    expect(e.okundu, isFalse);
  });

  test('yorum bildirimi ve güvenli olmayan avatar', () {
    final e = FkEtkilesim.fromJson({'tur': 'yorum', 'ad': 'Ali', 'avatar': 'http://x/y.jpg', 'okundu': true});
    expect(e.baslik, 'Ali avını yorumladı');
    expect(e.avatar, '');
    expect(e.okundu, isTrue);
  });

  test('paylaşımın sahibi bilgisi', () {
    expect(FkGonderi.fromJson({'id': '1', 'benim': true}).benim, isTrue);
    expect(FkGonderi.fromJson({'id': '1'}).benim, isFalse);
  });
}
