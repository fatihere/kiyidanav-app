// 1.17.0: haritada her kıyı noktası — yapışma mesafesi ve kesit önizleme metni
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/harita_secici.dart';
import 'package:kiyidanav/mera.dart';

void main() {
  test('kayıtlı meraya yapışma 400 m', () => expect(haritaYapisma, 0.4));

  test('kesit önizleme metni 50/100/200 m', () {
    final i = MeraInfo.fromJson({
      'd': [[25, 1.5], [50, 4.0], [100, 9.0], [150, 12.0], [200, 14.2], [300, 18.0]],
      'kaynak': 'EMODnet Bathymetry (nokta)',
    });
    expect(kesitOzeti(i), "50 m'de ~4 m · 100 m'de ~9 m · 200 m'de ~14 m");
  });
}
