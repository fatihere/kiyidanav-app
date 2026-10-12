import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/share.dart';

void main() {
  test('rapor görseli ~1080 px genişlikte üretilir (1,5x – 3x)', () {
    expect(Sharer.imagePixelRatio(360, 1080), 3.0);
    expect(Sharer.imagePixelRatio(400, 1080), closeTo(2.7, 0.001));
    expect(Sharer.imagePixelRatio(1000, 1080), 1.5);
    expect(Sharer.imagePixelRatio(0, 1080), 2.5);
  });
}
