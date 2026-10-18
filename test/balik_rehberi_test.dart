import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/balik_rehberi.dart';
import 'package:kiyidanav/sea.dart';

Spot _mera(String ad) => spots.firstWhere((s) => s.name == ad);

void main() {
  final ekim = DateTime(2026, 10, 18);

  test('Kartal (İstanbul): Ege türleri listelenmez, en olası türler başta', () {
    final l = bolgeTurleri(_mera('Kartal'), ekim);
    for (final yok in ['cupra', 'lidaki', 'sargoz', 'karagoz', 'mirmir', 'eskina', 'minekop']) {
      expect(l, isNot(contains(yok)), reason: yok);
    }
    expect(l.take(4), containsAll(['istavrit', 'lufer']));
  });

  test('Enez (Kuzey Ege): çupra ve lidaki var', () {
    final l = bolgeTurleri(_mera('Enez'), ekim);
    expect(l, containsAll(['cupra', 'lidaki', 'mirmir']));
  });

  test('Sıralama av ihtimaline göre azalan', () {
    final s = _mera('Urla');
    final b = balikBolgesi(s);
    final l = bolgeTurleri(s, ekim);
    for (var i = 1; i < l.length; i++) {
      expect(avIhtimali(b, l[i - 1], ekim), greaterThanOrEqualTo(avIhtimali(b, l[i], ekim)));
    }
  });

  test('Tablodaki her tür rehberde tanımlı', () {
    for (final m in bolgeAgirlik.values) {
      for (final k in m.keys) {
        expect(baliklar.containsKey(k), isTrue, reason: k);
      }
    }
  });
}
