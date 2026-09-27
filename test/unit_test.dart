import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/format.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/solunar.dart';

// Aşağıdaki JSON'lar sunucudaki mobil-api.php'nin test veritabanında
// ürettiği GERÇEK çıktılardır (sözleşme testi).
const homeJson = '''{"ok":true,"categories":[{"id":10,"name":"Olta Kamışları","image":"https://kiyidanav.com/image/catalog/kat/olta.jpg","has_children":true},{"id":20,"name":"Suni Yemler","image":null,"has_children":false}],"new":[{"id":1,"name":"Shimano Soare LRF & Aji Kamışı","brand":"Shimano","image":"https://kiyidanav.com/image/catalog/urun/lrf%201.jpg","price":3000,"special":2640,"in_stock":true},{"id":4,"name":"Albastar Suni Yem","brand":"Albastar","image":"https://kiyidanav.com/image/catalog/urun/suni.jpg","price":240,"special":null,"in_stock":true}]}''';
const productJson = '''{"ok":true,"id":1,"name":"Shimano Soare LRF & Aji Kamışı","brand":"Shimano","model":"SH-LRF","images":["https://kiyidanav.com/image/catalog/urun/lrf%201.jpg","https://kiyidanav.com/image/catalog/urun/lrf2.jpg"],"price":3000,"special":2640,"in_stock":true,"minimum":1,"description":"Hafif ve hassas.\\n• 2.10 m\\n• 1-7 g","options":[{"id":100,"name":"Boy","type":"select","required":true,"values":[{"id":1001,"name":"2.10 m","price":0,"in_stock":true},{"id":1002,"name":"2.40 m","price":300,"in_stock":false}]}],"url":"https://kiyidanav.com/index.php?route=product/product&product_id=1"}''';
const listJson = '''{"ok":true,"page":1,"pages":1,"total":1,"items":[{"id":1,"name":"Shimano Soare LRF & Aji Kamışı","brand":"Shimano","image":"https://kiyidanav.com/image/catalog/urun/lrf%201.jpg","price":3000,"special":2640,"in_stock":true}]}''';

void main() {
  group('Para biçimi', () {
    test('binlik ayırıcı ve kuruş', () {
      expect(tl(2640), '2.640,00 TL');
      expect(tl(95.5), '95,50 TL');
      expect(tl(1234567.891), '1.234.567,89 TL');
      expect(tl(0), '0,00 TL');
      expect(tl(-300), '-300,00 TL');
    });
  });

  group('API sözleşmesi', () {
    test('anasayfa çözümlenir', () {
      final h = HomeData.fromJson(jsonDecode(homeJson));
      expect(h.categories, isNotEmpty);
      expect(h.categories.first.name, 'Olta Kamışları');
      expect(h.categories.first.hasChildren, isTrue);
      expect(h.newArrivals.first.price, 3000); // 2500 + %20 KDV
      expect(h.newArrivals.first.special, 2640);
      expect(h.newArrivals.first.finalPrice, 2640);
    });

    test('ürün detayı ve seçenekler çözümlenir', () {
      final p = ProductDetail.fromJson(jsonDecode(productJson));
      expect(p.name, contains('Shimano'));
      expect(p.images.length, 2);
      expect(p.options.single.name, 'Boy');
      expect(p.options.single.values[1].price, 300);
      expect(p.options.single.values[1].inStock, isFalse);
      expect(p.description, contains('• 2.10 m'));
    });

    test('ürün listesi sayfalama bilgisi', () {
      final r = PageResult.fromJson(jsonDecode(listJson));
      expect(r.total, 1);
      expect(r.hasMore, isFalse);
    });

    test('eksik/bozuk alanlar çökertmez', () {
      final p = ProductCard.fromJson({'id': '7', 'price': 'abc'});
      expect(p.id, 7);
      expect(p.price, 0);
      expect(p.name, '');
    });
  });

  group('Sepet', () {
    CartItem item(int qty, List<SelectedOption> o) => CartItem(
        product: const ProductCard(id: 1, name: 'X', price: 100),
        options: o,
        unitPrice: 120,
        qty: qty);

    test('aynı ürün + aynı seçenek aynı anahtarı üretir (sıra fark etmez)', () {
      const a = SelectedOption(optionId: 1, valueId: 2, type: 'select', label: '');
      const b = SelectedOption(optionId: 3, valueId: 4, type: 'select', label: '');
      expect(item(1, [a, b]).key, item(5, [b, a]).key);
      expect(item(1, [a]).key == item(1, [b]).key, isFalse);
    });

    test('toplam ve JSON gidiş-dönüş', () {
      final c = item(3, const [
        SelectedOption(optionId: 1, valueId: 2, type: 'select', label: 'Boy: 2.40 m')
      ]);
      expect(c.total, 360);
      final back = CartItem.fromJson(jsonDecode(jsonEncode(c.toJson())));
      expect(back.key, c.key);
      expect(back.qty, 3);
      expect(back.options.single.label, 'Boy: 2.40 m');
    });
  });

  group('Deniz durumu', () {
    test('değerlendirme eşikleri', () {
      expect(const SeaReport(windKmh: 8, waveM: 0.2).verdict, 'Kıyıdan atış için ideal');
      expect(const SeaReport(windKmh: 20, waveM: 0.7).isGood, isTrue);
      expect(const SeaReport(windKmh: 45, waveM: 2.5).verdict, contains('Fırtınalı'));
    });

    test('rüzgâr adları', () {
      expect(const SeaReport(windDir: 225).windFrom, 'Lodos');
      expect(const SeaReport(windDir: 45).windFrom, 'Poyraz');
      expect(const SeaReport(windDir: 0).windFrom, 'Yıldız');
    });
  });

  group('Ay evresi ve av verimliliği', () {
    test('21 Eylül 2026 = İlk Şişkin Ay, %70 (İstanbul av raporu ile aynı)', () {
      final d = DateTime.utc(2026, 9, 21, 12);
      expect(Moon.phaseName(d), 'İlk Şişkin Ay');
      expect(Moon.baseScore(d), 70);
    });
    test('26 Eylül 2026 dolunay', () {
      expect(Moon.phaseName(DateTime.utc(2026, 9, 26, 18)), 'Dolunay');
      expect(Moon.illumination(DateTime.utc(2026, 9, 26, 18)), greaterThan(0.97));
    });
    test('fırtına verimliliği düşürür, sakin hava artırır', () {
      final d = DateTime.utc(2026, 9, 26, 18);
      final calm = FishingScore.compute(d, windKmh: 8, waveM: 0.4);
      final storm = FishingScore.compute(d, windKmh: 40, waveM: 2.2);
      expect(calm, greaterThan(storm));
      expect(calm, inInclusiveRange(10, 98));
      expect(storm, inInclusiveRange(10, 98));
      expect(FishingScore.fishCount(calm), inInclusiveRange(1, 5));
    });
  });

  group('v2 sözleşmesi', () {
    test('vitrin bölümleri ve ayarlar çözümlenir', () {
      final h = HomeData.fromJson(jsonDecode(
          '{"ok":true,"categories":[],"sections":[{"id":815,"title":"Hazır Olta Setleri","items":[{"id":1,"name":"Set","brand":null,"image":"https://kiyidanav.com/image/a.jpg","price":1200,"special":null,"in_stock":true}]}],"new":[]}'));
      expect(h.sections.single.title, 'Hazır Olta Setleri');
      expect(h.sections.single.items.single.price, 1200);
      final c = RemoteConfig.fromJson(jsonDecode(
          '{"ok":true,"duyuru":"Kargo bedava","dalga_esik":1.2,"paylas_metin":"","telefon":"+90","ay":9,"yem":[{"balik":"Palamut","canli":"-","sahte":"Jig","ara":"jig"}]}'));
      expect(c.announcement, 'Kargo bedava');
      expect(c.waveThreshold, 1.2);
      expect(c.shareText, contains('KıyıdanAv'));
      expect(c.bait.single.fish, 'Palamut');
      expect(c.bait.single.search, 'jig');
    });
    test('yaka noktaları: Anadolu Riva–Darıca, Avrupa Semizkum dahil', () {
      expect(spotsOf(Side.anadolu).first.name, 'Riva');
      expect(spotsOf(Side.anadolu).last.name, 'Darıca');
      expect(spotsOf(Side.avrupa).map((s) => s.name), contains('Semizkum'));
    });
  });
}
