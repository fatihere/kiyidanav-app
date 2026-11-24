import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/meraya.dart';

void main() {
  test('sunucu yanıtı çözülür', () {
    final o = MerayaOzet.json({
      'ok': true,
      'otopark': [
        {'ad': 'Sarayburnu Otopark', 'lat': 41.01686, 'lon': 28.98406, 'mesafe_m': 207, 'ucret': '', 'kapasite': 0, 'tur': 'açık'},
        {'ad': '', 'lat': 41.0152, 'lon': 28.97622, 'mesafe_m': 1653, 'ucret': 'ücretli', 'kapasite': 40, 'tur': 'katlı'},
      ],
      'otopark_hata': false,
      'kamera': [
        {'ad': 'Kadıköy', 'kaynak': 'İBB', 'url': 'u1', 'mesafe_m': 900, 'kapali': 'KVKK', 'resmi': true},
        {'ad': 'Eminönü', 'kaynak': 'İBB', 'url': 'u2', 'mesafe_m': 979, 'kapali': '', 'resmi': true},
      ],
      'yogunluk': {'sakin': 1, 'normal': 3, 'kalabalik': 0, 'son_dk': 12},
    });
    expect(o.otopark.length, 2);
    expect(o.otopark.first.alt, '207 m');
    expect(o.otopark.last.baslik, 'Otopark');
    expect(o.otopark.last.alt, '1,7 km · katlı · ücretli · 40 araç');
    expect(o.ilkAcikKamera?.ad, 'Eminönü');
    expect(o.yogunluk.baskin, 1);
    expect(o.yogunluk.ozet, 'Normal · son 2 saatte 4 bildirim (en son 12 dk önce)');
  });

  test('bildirim yoksa ve eşitlikte kalabalık öne geçer', () {
    expect(const MerayaYogunluk(0, 0, 0).baskin, isNull);
    expect(const MerayaYogunluk(0, 0, 0).ozet, startsWith('Son 2 saatte bildirim yok'));
    expect(const MerayaYogunluk(2, 0, 2, 0).baskin, 2);
    expect(MerayaOzet.json({'yogunluk': null}).yogunluk.toplam, 0);
  });

  test('yol tarifi bağlantıları', () {
    expect(googleYol(41.0, 29.0).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=41.0%2C29.0&travelmode=driving');
    expect(yandexYol(41.0, 29.0).toString(), 'yandexnavi://build_route_on_map?lat_to=41.0&lon_to=29.0');
    expect(appleYol(41.0, 29.0).queryParameters['daddr'], '41.0,29.0');
  });
}
