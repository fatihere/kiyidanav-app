import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/catches.dart';
import 'package:kiyidanav/format.dart';
import 'package:kiyidanav/mera_widget.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/notices.dart';
import 'package:kiyidanav/overlays.dart';
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/screens/knots_screen.dart';
import 'package:kiyidanav/solunar.dart';
import 'package:kiyidanav/ui.dart';
import 'package:kiyidanav/weather_icon.dart';
import 'package:kiyidanav/config.dart';
import 'package:flutter/material.dart' show Color;

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

  group('Deniz yorumu (hamle ve yağış dahil)', () {
    test('25 km/s rüzgâr + 40 km/s hamle + yağış artık "Uygun" sayılmaz', () {
      const r = SeaReport(windKmh: 24.5, gustKmh: 40.3, waveM: 0.2, waveMax6h: 0.46, rainNow: 0, rainDay: 15.2);
      expect(r.effectiveWind, closeTo(28.2, 0.1));
      expect(r.verdict, startsWith('Sert'));
      expect(r.verdict, contains('yağışlı'));
      expect(r.isGood, isFalse);
    });
    test('sakin hava ideal', () {
      const r = SeaReport(windKmh: 8, gustKmh: 12, waveM: 0.2, waveMax6h: 0.3, rainDay: 0);
      expect(r.verdict, 'Kıyıdan atış için ideal');
    });
    test('6 saat içindeki en yüksek dalga dikkate alınır', () {
      const r = SeaReport(windKmh: 10, gustKmh: 14, waveM: 0.3, waveMax6h: 1.2);
      expect(r.effectiveWave, 1.2);
      expect(r.verdict, startsWith('Sert'));
    });
    test('Boğaz içinde dalga verisi kullanılmaz', () {
      const r = SeaReport(windKmh: 10, gustKmh: 12, waveM: 2.4, strait: true);
      expect(r.effectiveWave, 0);
      expect(spots.where((s) => s.strait).map((s) => s.name), containsAll(['Sarıyer', 'Bebek', 'Beykoz']));
    });
    test('saatlik seriden önümüzdeki saatlerin en büyüğü', () {
      final hourly = {
        'time': ['2026-09-29T17:00', '2026-09-29T18:00', '2026-09-29T19:00', '2026-09-29T23:00', '2026-09-30T02:00'],
        'wave_height': [0.9, 0.2, 0.4, 0.6, 1.5],
      };
      final v = SeaService.maxNextHours(hourly, 'wave_height', 6, now: DateTime(2026, 9, 29, 18, 20));
      expect(v, 0.6); // 17:00 geçmişte, 02:00 altı saatin dışında
    });
    test('yağış verimliliği düşürür', () {
      final d = DateTime.utc(2026, 9, 26, 18);
      expect(FishingScore.compute(d, windKmh: 10, rainMm: 25), lessThan(FishingScore.compute(d, windKmh: 10, rainMm: 0)));
    });
  });

  group('v1.6: panelden görünüm, kamp, düğüm, akıntı', () {
    test('tema: boş gelirse varsayılan, gelen renk/boyut uygulanır, aralık dışı sınırlanır', () {
      const d = Ui();
      final u = Ui.fromJson({'yem_baslik_zemin': '#E65100', 'bolum_baslik_boyut': '99', 'mera_ses_acik': true, 'vurgu': 'bozuk'});
      expect(u.yemBaslikZemin, const Color(0xFFE65100));
      expect(u.bolumBaslikBoyut, 28);
      expect(u.meraSesAcik, isTrue);
      expect(u.vurgu, d.vurgu);
      final c = RemoteConfig.fromJson(jsonDecode('{"ok":true,"tema":{"zemin":"#ffffff"},"dugum_acik":false}'));
      expect(c.ui.zemin, const Color(0xFFFFFFFF));
      expect(c.knots, isFalse);
      expect(RemoteConfig.fromJson(jsonDecode('{"ok":true}')).knots, isTrue);
    });
    test('kamp satırları vitrinlerin arasına yerleşir', () {
      HomeSection s(int id) => HomeSection(id: id, title: '$id', items: const []);
      final h = HomeData(categories: const [], newArrivals: const [], sections: [s(1), s(2), s(3), s(4)]);
      final camp = [HomeSection(id: 90, title: 'Çadır', items: const [], random: true), HomeSection(id: 91, title: 'Termos', items: const [], random: true)];
      expect(h.mixed(camp).map((e) => e.id).toList(), [1, 90, 2, 3, 91, 4]);
      expect(HomeData(categories: const [], newArrivals: const []).mixed(camp).length, 2);
      final j = HomeData.fromJson(jsonDecode('{"categories":[],"new":[],"camp":[{"id":315,"title":"Çadırlar","random":true,"items":[{"id":1,"name":"Çadır","price":10}]},{"id":1,"title":"Boş","items":[]}]}'));
      expect(j.camp.single.title, 'Çadırlar');
      expect(j.camp.single.random, isTrue);
    });
    test('yem satırında kategori', () {
      final r = BaitRow.fromJson({'balik': 'Çinekop', 'canli': '-', 'sahte': 'Kaşık', 'ara': 'kaşık', 'kategori': 405});
      expect(r.category, 405);
      expect(BaitRow.fromJson({'balik': 'L'}).category, 0);
    });
    test('düğüm çözümlenir, video kimliği doğrulanır', () {
      final k = Knot.fromJson({'ad': 'Palomar', 'grup': 'İğne', 'kullanim': 'x', 'adimlar': ['a', '', 'b'], 'video': 'OITMtq9Jdgw', 'zorluk': 7});
      expect(k.steps, ['a', 'b']);
      expect(k.level, 3);
      expect(k.videoUri.queryParameters['v'], 'OITMtq9Jdgw');
      final bad = Knot.fromJson({'ad': 'X', 'video': 'javascript:alert(1)'});
      expect(bad.video, isEmpty);
      expect(bad.videoUri.host, 'www.youtube.com');
    });
    test('üç model uyumu', () {
      final now = DateTime(2026, 10, 12, 10);
      final times = List.generate(8, (i) => '2026-10-12T${(10 + i).toString().padLeft(2, '0')}:00');
      final c = ModelConsensus.fromHourly({
        'time': times,
        'wind_speed_10m_icon_seamless': [10, 12, 11, 9, 8, 7, 30, 30],
        'wind_speed_10m_gfs_seamless': [11, 13, 12, 10, 9, 8, 30, 30],
        'wind_speed_10m_ecmwf_ifs025': [9, 10, 14, 10, 9, 8, 30, 30],
      }, now: now)!;
      expect(c.count, 3);
      expect(c.windMax['ECMWF'], 14);
      expect(c.level, 'Yüksek');
      expect(ModelConsensus.fromHourly({'time': times}, now: now), isNull);
    });
    test('hafif akıntı verimliliği artırır, sert akıntı düşürür', () {
      final d = DateTime.utc(2026, 10, 3, 12);
      final base = FishingScore.compute(d, windKmh: 12);
      expect(base, lessThan(95));
      expect(FishingScore.compute(d, windKmh: 12, currentKmh: 1.0), greaterThan(base));
      expect(FishingScore.compute(d, windKmh: 12, currentKmh: 4.0), lessThan(base));
    });
  });

  group('av bildirimleri ve uydu', () {
    test('av çözümlenir; en fazla 3 güvenli fotoğraf', () {
      final c = CatchReport.fromJson(jsonDecode(
          '{"id":"a1","mera":"Kartal","balik":"Lüfer","adet":3,"kg":1.25,"yem":"Maket","ad":"Fatih Y.","saat":"2026-10-12T06:30","fotolar":["https://kiyidanav.com/a.jpg","http://x/b.jpg","https://kiyidanav.com/c.jpg","https://kiyidanav.com/d.jpg","https://kiyidanav.com/e.jpg"]}'));
      expect(c.photos.length, 3);
      expect(c.photos.every((p) => p.startsWith('https://')), isTrue);
      expect(c.amount, '3 adet · 1,3 kg');
      expect(c.ago(DateTime(2026, 10, 12, 11, 30)), '5 saat önce');
    });
    test('uydu yorumu ve puana etkisi', () {
      final s = SatInfo.fromJson(jsonDecode('{"ok":true,"sst":{"deger":18.4,"degisim5":-1.1},"klorofil":{"deger":2.7,"degisim_yuzde":22}}'));
      expect(s.comment(10), contains('göçü'));
      expect(s.comment(10), contains('Klorofil artıyor'));
      expect(SatInfo.fromJson(jsonDecode('{"ok":true,"sst":null,"klorofil":null}')).isEmpty, isTrue);
      final d = DateTime(2026, 10, 3, 12);
      final base = FishingScore.compute(d, windKmh: 12);
      expect(FishingScore.compute(d, windKmh: 12, recentCatches: 5), base + 9 > 98 ? 98 : base + 9);
      expect(FishingScore.compute(d, windKmh: 12, sstChange5d: -1.0, chlChangePct: 20), greaterThan(base));
      expect(FishingScore.compute(DateTime(2026, 6, 3, 12), windKmh: 12, sstChange5d: -1.0),
          FishingScore.compute(DateTime(2026, 6, 3, 12), windKmh: 12));
    });
  });

  group('Eklentiler (aç/kapa)', () {
    test('eksik anahtar açık sayılır, kapatılan kapanır', () {
      final c = RemoteConfig.fromJson({
        'eklentiler': {'uydu': false, 'kamp': false, 'dugum': false, 'av_bildirim': true},
      });
      expect(c.features.satellite, isFalse);
      expect(c.features.camp, isFalse);
      expect(c.features.catchSubmit, isTrue);
      expect(c.features.ambientSound, isTrue);
      expect(c.knots, isFalse);
    });
    test('eski sunucu (eklentiler yok) her şeyi açık bırakır', () {
      final c = RemoteConfig.fromJson({'dugum_acik': true});
      expect(c.features.catchList, isTrue);
      expect(c.features.notificationSound, isTrue);
      expect(c.knots, isTrue);
    });
    test('rapor açıklaması kapalı kaynakları saymaz', () {
      final t = scoreSourcesText(const Features({'uydu': false, 'av_listesi': false}));
      expect(t.contains('klorofil'), isFalse);
      expect(t.contains('av bildirim'), isFalse);
      expect(t.contains('rüzgâr'), isTrue);
    });
  });

  group('Instagram hesabı', () {
    test('@, bağlantı ve büyük harf temizlenir', () {
      expect(CatchService.normalizeInstagram('@KiyidanAv'), 'kiyidanav');
      expect(CatchService.normalizeInstagram('https://www.instagram.com/kiyida.birivar/'), 'kiyida.birivar');
      expect(CatchService.normalizeInstagram(' fatih_eren '), 'fatih_eren');
    });
    test('geçersizler reddedilir', () {
      expect(CatchService.normalizeInstagram(''), isNull);
      expect(CatchService.normalizeInstagram('fatih eren'), isNull);
      expect(CatchService.normalizeInstagram('ad..soyad'), isNull);
      expect(CatchService.normalizeInstagram('a' * 31), isNull);
    });
    test('av bildirimi mera bilgisi ve hesap okunur', () {
      final c = CatchReport.fromJson({
        'id': 'x', 'mera': 'Moda', 'balik': 'Lüfer', 'mera_bilgi': 'Taşlık dip',
        'instagram': '@Avci', 'ig_link': 'https://www.instagram.com/p/abc/',
      });
      expect(c.spotInfo, 'Taşlık dip');
      expect(c.instagram, 'avci');
      expect(c.igLink, 'https://www.instagram.com/p/abc/');
      expect(CatchReport.fromJson({'ig_link': 'https://kotu.example/'}).igLink, '');
    });
  });

  group('1.7.0', () {
    test('hava kodu simgesi ve adı', () {
      expect(WeatherLook.of(0).label, 'Güneşli, açık');
      expect(WeatherLook.of(3).label, 'Kapalı, bulutlu');
      expect(WeatherLook.of(63).label, 'Yağmurlu');
      expect(WeatherLook.of(95).label, 'Gök gürültülü sağanak');
      expect(WeatherLook.of(null).label, 'Hava bilgisi yok');
      expect(WeatherLook.of(1234).label, 'Hava bilgisi yok');
    });

    test('günlük baskın rüzgâr adı', () {
      expect(DayForecast(date: DateTime(2026, 10, 12), windDir: 30).windFrom, 'Poyraz');
      expect(DayForecast(date: DateTime(2026, 10, 12), windDir: 220).windFrom, 'Lodos');
      expect(DayForecast(date: DateTime(2026, 10, 12)).windFrom, '');
    });

    test('kampanya bandı: rapor ve kapatılanlar gösterilmez, eskiler düşer', () {
      final now = DateTime.now();
      String d(int daysAgo) => now.subtract(Duration(days: daysAgo)).toIso8601String().substring(0, 19).replaceFirst('T', ' ');
      final all = [
        Notice(id: 'a', type: 'kampanya', title: 'İndirim', body: '', date: d(1)),
        Notice(id: 'b', type: 'rapor', title: 'Rapor', body: '', date: d(0)),
        Notice(id: 'c', type: 'urun', title: 'Yeni ürün', body: '', date: d(2)),
        Notice(id: 'e', type: 'kampanya', title: 'Eski', body: '', date: d(10)),
      ];
      expect(CampaignTicker.active(all, {}).map((n) => n.id), ['a', 'c']);
      expect(CampaignTicker.active(all, {'a'}).map((n) => n.id), ['c']);
    });

    test('ana ekran kartı: panel anahtarı ve dokunma bağlantısı', () {
      expect(const Features().homeWidget, isTrue);
      expect(Features.fromJson({'widget': false}).homeWidget, isFalse);
      expect(MeraWidget.isWidgetLink(Uri.parse('kiyidanav://mera')), isTrue);
      expect(MeraWidget.isWidgetLink(Uri.parse('https://kiyidanav.com/')), isFalse);
      expect(MeraWidget.isWidgetLink(null), isFalse);
    });

    test('POST istekleri yönlendirilmesin diye site adresi www ile', () {
      expect(AppConfig.siteUrl, 'https://www.kiyidanav.com/');
      expect(Uri.parse(AppConfig.apiUrl).host, 'www.kiyidanav.com');
      expect('www.kiyidanav.com'.endsWith(AppConfig.siteHost), isTrue);
    });
  });
}
