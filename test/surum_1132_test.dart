import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/sea.dart';

void main() {
  test('haritadan öğrenilen mera adıyla saklanır ve geri okunur', () {
    final sariyer = spots.firstWhere((s) => s.name == 'Sarıyer');
    final s = Spot.pin(41.1753, 29.0889, sariyer, ad: 'Anadolu Kavağı, Beykoz', side: Side.anadolu);
    expect(s.ogrenilmis, isTrue);
    expect(s.key, 'Sarıyer');
    final k = spotToKey(s);
    final g = spotFromKey(k);
    expect(g.name, 'Anadolu Kavağı, Beykoz');
    expect(g.side, Side.anadolu);
    expect(g.lat, closeTo(41.1753, 0.0001));
    expect(g.ref, 'Sarıyer');
  });

  test('eski "X yakını" kayıtları bozulmadan okunur', () {
    final g = spotFromKey('pin|41.1000|29.0500|Sarıyer');
    expect(g.name, 'Sarıyer yakını');
    expect(g.ogrenilmis, isFalse);
    expect(spotToKey(g), 'pin|41.1000|29.0500|Sarıyer');
  });
}
