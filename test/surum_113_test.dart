import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/notices.dart';
import 'package:kiyidanav/yonetici.dart';

void main() {
  test('kalama sesi süresi panelden 1–10 sn okunur', () {
    expect(RemoteConfig.fromJson({'kalama_sure': 4}).kalamaSure, 4);
    expect(RemoteConfig.fromJson({'kalama_sure': 25}).kalamaSure, 10);
    expect(RemoteConfig.fromJson({'kalama_sure': '0'}).kalamaSure, 10);
    expect(RemoteConfig.fromJson(const {}).kalamaSure, 10);
    Notices.kalamaSure = 3;
    expect(Notices.kalamaKanal, 'kiyidanav_kalama_3');
    Notices.kalamaSure = 10;
  });

  test('KıyıdanPaylaş ve mesaj bildirimleri telefonun kendi sesiyle', () {
    expect(Notices.toplulukTipi('paylas'), isTrue);
    expect(Notices.toplulukTipi('mesaj'), isTrue);
    expect(Notices.toplulukTipi('kampanya'), isFalse);
  });

  test('yönetici oturumu yalnız geçerli biçimde okunur', () {
    final g = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final o = YoneticiOturum.fromJson({
      'oturum': 'a' * 32,
      'ad': 'Fatih',
      'gecerlilik': g,
      'paneller': [
        {'id': 'mobil', 'ad': 'Mobil uygulama paneli', 'url': 'https://www.kiyidanav.com/instagram/mobil.php'},
        {'id': 'kotu', 'ad': 'Güvensiz', 'url': 'http://ornek.com'},
      ],
    });
    expect(o, isNotNull);
    expect(o!.gecerli, isTrue);
    expect(o.paneller.length, 1);
    expect(YoneticiOturum.fromJson({'oturum': 'kisa', 'gecerlilik': g}), isNull);
    expect(YoneticiOturum.fromJson({'oturum': 'b' * 32, 'gecerlilik': 10})!.gecerli, isFalse);
  });
}
