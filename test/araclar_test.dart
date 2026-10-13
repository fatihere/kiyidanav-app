import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiyidanav/araclar.dart';
import 'package:kiyidanav/cevrimdisi.dart';
import 'package:kiyidanav/moduller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Turnuva', () {
    final l = [
      {'ad': 'Ekim LRF', 'bas': '2026-10-10', 'bit': '2026-10-13', 'tur': 'İstavrit', 'kural': 'En çok adet'},
      {'ad': 'Kasım Levrek', 'bas': '2026-11-01', 'bit': '2026-11-30', 'tur': 'Levrek', 'kural': 'En uzun'},
      {'ad': '', 'bas': '2026-10-01', 'bit': '2026-10-31'},
      {'ad': 'Tarihsiz'},
    ];
    test('yalnız süren turnuvalar (bitiş günü dahil)', () {
      final a = aktifTurnuvalar(l, DateTime(2026, 10, 13, 22, 30));
      expect(a.map((t) => t['ad']), ['Ekim LRF']);
      expect(aktifTurnuvalar(l, DateTime(2026, 10, 14)), isEmpty);
      expect(aktifTurnuvalar(l, DateTime(2026, 11, 1, 6)).map((t) => t['ad']), ['Kasım Levrek']);
    });
    test('günün kodu sunucuyla aynı biçimde', () {
      expect(gununKodu('KA-{GÜN}', DateTime(2026, 10, 3)), 'KA-0310');
      expect(gununKodu('{TARIH} kodu', DateTime(2026, 1, 9)), '09.01 kodu');
    });
  });

  group('Ürün parçaları', () {
    test('sunucu yanıtı okunur, güvensiz bağlantılar elenir', () {
      final u = UrunAraclari.fromJson({
        'ok': true,
        'buUrunle': {
          'baslik': 'Bu ürünle tutuldu',
          'avlar': [
            {'foto': 'https://kiyidanav.com/image/a.jpg', 'balik': 'Levrek', 'mera': 'Kartal', 'ad': 'Ali K.'},
            {'foto': 'http://kotu.example/a.jpg'},
          ],
        },
        'stok': {'buton': 'Stoğa gelince haber ver'},
        'video': {
          'baslik': 'Videolar',
          'liste': [
            {'id': 'abcDEF12345', 'baslik': 'LRF'},
            {'id': '"><script>', 'baslik': 'kötü'},
          ],
        },
      });
      expect(u.avlar.length, 1);
      expect(u.stokButon, 'Stoğa gelince haber ver');
      expect(u.videolar.length, 1);
      expect(u.bos, isFalse);
      expect(UrunAraclari.fromJson({'ok': true}).bos, isTrue);
    });
    test('tür tanıma sonucu', () {
      final t = TaniSonuc.fromJson({
        'ok': true, 'tur': 'Levrek', 'guven': 88, 'emin': true, 'boy_tahmini': 21.5, 'asgari_boy': 25,
        'uyarilar': ['Asgari avlanma boyu: 25 cm.'], 'alternatifler': ['Lahoz'],
      });
      expect(t.ok, isTrue);
      expect(t.tur, 'Levrek');
      expect(t.boyTahmini, 21.5);
      expect(t.asgariBoy, 25);
      expect(t.uyarilar.single, contains('25'));
      expect(TaniSonuc.fromJson({'ok': false, 'hata': 'kapalı'}).hata, 'kapalı');
    });
  });

  group('Araç listesi', () {
    test('yalnız panelde açık araçlar, sıraya göre', () {
      Moduller.uyeNo = 0;
      Moduller.yukle({
        'moduller': {
          'video': {'test': false, 'app': true, 'uye': false, 'sira': 5},
          'gunluk': {'test': false, 'app': true, 'uye': true, 'sira': 2, 'baslik': 'Günlüğüm'},
          'sonar': {'test': true, 'app': true},
          'hesaplayici': {'test': false, 'app': false, 'web': true},
        },
      });
      final l = Araclar.acik();
      expect(l.map((e) => e.$1.id), ['gunluk', 'video']);
      expect(Araclar.ad(l.first.$1, l.first.$2), 'Günlüğüm');
      expect(Araclar.ad(l.last.$1, l.last.$2), 'Videolu anlatım');
    });
  });

  group('Çevrimdışı mod', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Cevrimdisi.kullanilan.value = null;
    });
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=40.9');

    test('modül açıkken son yanıt saklanır ve internet yokken gösterilir', () async {
      Moduller.yukle({
        'moduller': {
          'cevrimdisi': {'test': false, 'app': true, 'uye': true, 'ayar': {'saat': 12}},
        },
      });
      Cevrimdisi.istemci = MockClient((_) async => http.Response('{"a":1,"ş":"ğ"}', 200, headers: {'content-type': 'application/json; charset=utf-8'}));
      final r1 = await Cevrimdisi.get(uri);
      expect(r1.statusCode, 200);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(Cevrimdisi.kullanilan.value, isNull);

      Cevrimdisi.istemci = MockClient((_) async => throw const SocketException('yok'));
      final r2 = await Cevrimdisi.get(uri);
      expect(r2.body, '{"a":1,"ş":"ğ"}');
      expect(Cevrimdisi.kullanilan.value, isNotNull);
    });

    test('modül kapalıyken saklanmaz, hata aynen iletilir', () async {
      Moduller.yukle({'moduller': {}});
      Cevrimdisi.istemci = MockClient((_) async => http.Response('{"b":2}', 200));
      await Cevrimdisi.get(uri);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Cevrimdisi.istemci = MockClient((_) async => throw const SocketException('yok'));
      await expectLater(Cevrimdisi.get(uri), throwsA(anything));
    });

    test('ayar dosyası modülden bağımsız saklanır', () async {
      Moduller.yukle({'moduller': {}});
      final cfg = Uri.parse('https://www.kiyidanav.com/mobil-api.php?a=config');
      Cevrimdisi.istemci = MockClient((_) async => http.Response('{"ok":true}', 200));
      await Cevrimdisi.get(cfg, herZaman: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Cevrimdisi.istemci = MockClient((_) async => throw const SocketException('yok'));
      final r = await Cevrimdisi.get(cfg, herZaman: true);
      expect(r.body, '{"ok":true}');
      expect(Cevrimdisi.kullanilan.value, isNull);
    });
  });
}
