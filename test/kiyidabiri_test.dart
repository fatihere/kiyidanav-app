import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/freshwater.dart';
import 'package:kiyidanav/kiyidabiri_beyin.dart';
import 'package:kiyidanav/locate.dart';
import 'package:kiyidanav/mera.dart';
import 'package:kiyidanav/mera_oner.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/sea.dart';

/// Ağsız sahte veri: Kartal sakin, Riva dalgalı (surf için ideal), Beykoz Boğaz içi
class SahteVeri implements KbVeri {
  final pin = Spot.pin(40.9, 29.2, spots.firstWhere((s) => s.name == 'Kartal'), ad: 'Gizli koy');
  @override
  Future<Spot?> yerBul(String ad) async {
    if (!ad.contains('diliskele')) return null;
    final (yakin, _) = Locate.nearest(40.7757, 29.5268);
    return Spot.pin(40.7757, 29.5268, yakin, ad: 'Diliskelesi, Dilovası');
  }
  @override
  Spot get secili => spots.firstWhere((s) => s.name == 'Kartal');
  @override
  bool get uye => false;
  @override
  List<Spot> denizMeralari() => [pin, ...spots.where((s) => s.side.public)];
  @override
  List<MeraOnerisi> topluluk() => const [
        MeraOnerisi(id: 1, tur: MeraTuru.tatli, ad: 'Sapanca Kurtköy', lat: 40.7, lon: 30.2, baliklar: ['Sazan'], oneren: 'Ali Yılmaz'),
      ];
  @override
  Future<FwData?> tatliSu() async => null;

  SeaReport _r(Spot s) {
    if (s.name == 'Riva') return const SeaReport(windKmh: 14, gustKmh: 20, waveM: 0.8, waveMax6h: 0.9, seaC: 17, airC: 18);
    if (s.strait) return const SeaReport(windKmh: 10, gustKmh: 14, strait: true, seaC: 16, airC: 18);
    return const SeaReport(windKmh: 8, gustKmh: 12, waveM: 0.1, waveMax6h: 0.15, seaC: 17, airC: 18);
  }

  @override
  Future<SpotForecast> hafta(Spot s) async => SpotForecast(spot: s, now: _r(s), days: [
        DayForecast(date: DateTime(2026, 11, 6), sunrise: DateTime(2026, 11, 6, 7, 2), sunset: DateTime(2026, 11, 6, 17, 1)),
        DayForecast(date: DateTime(2026, 11, 7), windMax: 28, gustMax: 41, waveMax: 1.4, tempMin: 11, tempMax: 17, windDir: 30,
            rainProb: 60, sunrise: DateTime(2026, 11, 7, 7, 3), sunset: DateTime(2026, 11, 7, 17, 0)),
      ]);
  @override
  Future<List<SpotForecast>> simdi(List<Spot> l) async => [for (final s in l) SpotForecast(spot: s, now: _r(s))];
  @override
  Future<MeraInfo?> kesit(Spot s) async =>
      const MeraInfo(dip: 'Kaya → kum', profile: [MapEntry(50, 4.0), MapEntry(100, 9.0)], note: 'Akşamüstü levrek');
  final talepler = <Map<String, String>>[];
  @override
  Future<bool> tekneTalep(Map<String, String> talep) async {
    talepler.add(talep);
    return true;
  }

  @override
  Future<List<KbBlogYazi>> blog() async => const [
        KbBlogYazi('Kiyidan Mirmir Avi Nasil Yapilir, Hangi Meralar ve Yem Kullanilir.', 'Mırmır gece kum zeminde tutulur.',
            'https://www.kiyidanav.com/kiyidan-av-yontemleri/mirmir'),
        KbBlogYazi('Amatör Balıkçı Belgesi Nasıl Alınır? 2026 Rehber', 'Belge e-Devlet üzerinden alınır.',
            'https://www.kiyidanav.com/kiyidan-av-yontemleri/belge'),
      ];

  @override
  Future<List<ProductCard>> indirimliler() async => const [ProductCard(id: 9, name: 'Daiwa Ninja LT 3000', price: 2000, special: 1500)];
  @override
  Future<List<String>> kampanyaDuyurulari() async => const ['Kasım indirimi: makinelerde %20'];

  @override
  Future<List<ProductCard>> urunAra(String q) async => const [
        ProductCard(id: 7, name: 'Shimano Sienna 2500', price: 1500, special: 1200),
        ProductCard(id: 8, name: 'Daiwa RX', price: 900),
      ];
}

void main() {
  test('Türkçe sadeleştirme', () {
    expect(kbNorm("Bugün Rumelifeneri'ndeyim!"), 'bugun rumelifenerindeyim');
    expect(kbNorm('KURŞUN ARKASI'), 'kursun arkasi');
  });

  test('stil bulma', () {
    expect(kbStilBul('lrf yapıyorum')?.ad, 'LRF');
    expect(kbStilBul('Kurşun arkası')?.ad, 'Kurşun arkası');
    expect(kbStilBul('surfcasting')?.ad, 'Surf');
    expect(kbStilBul('bilmiyorum'), isNull);
  });

  test('soru-cevap: mera → stil → ekipman → kampanya', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    expect(b.adim, KbAdim.serbest);
    final y1 = await b.yanitla('Bugün kartaldayım');
    expect(y1.niyet, 'mera');
    expect(y1.metin, contains('Kartal'));
    expect(y1.metin, contains('Dip yapısı: Kaya → kum'));
    expect(y1.metin, isNot(contains('Hangi stilde')));

    final y2 = await b.yanitla('surf');
    expect(y2.metin, contains('en uygun mera: Riva'));
    expect(y2.secenekler.first.gonder, 'Surf ekipmanı');

    final y3 = await b.yanitla('Surf ekipmanı');
    expect(y3.metin, contains('4,20–4,50 m'));
    expect(y3.metin, contains('Shimano Sienna 2500'));
    expect(y3.secenekler.first.eylem, KbEylem.urunAc);

    final y4 = await b.yanitla('kampanyalar');
    expect(y4.niyet, 'kampanya_liste');
    expect(y4.metin, contains('Daiwa Ninja LT 3000'));
    expect(y4.metin, contains('Kasım indirimi'));

    final y5 = await b.yanitla('makine için indirim olunca haber ver');
    expect(y5.niyet, 'kampanya_sor');
    final y6 = await b.yanitla('Olta makinesi');
    expect(y6.kampanya, 'Olta makinesi');
  });

  test('balığa göre ekipman', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final y = await b.yanitla('levrek için hangi makine alayım');
    expect(y.metin, contains('Spin için ekipman'));
    expect(y.metin, contains('3000–4000'));
  });

  test('1.16.0: listede olmayan yer adı haritada bulunur, körfezde doğru kıyı', () async {
    final b = KiyidabiriBeyin(SahteVeri())..adim = KbAdim.mera;
    final y = await b.yanitla('diliskelesi');
    expect(y.niyet, 'mera');
    expect(y.metin, contains('Diliskelesi, Dilovası'));
    expect(y.metin, contains('İzmit Körfezi'));
    expect(y.metin, isNot(contains('Çanakkale')));
    // Dilovası kuzey kıyıda: en yakın mera karşı kıyıdaki Altınova değil
    final (yakin, _) = Locate.nearest(40.7757, 29.5268);
    expect(yakin.side, Side.izmit);
    expect(Locate.korfezKiyisi(40.7757, 29.5268), 'kuzey');
    expect(Locate.korfezKiyisi(40.705, 29.505), 'guney');
    expect(Locate.korfezKiyisi(41.0, 29.0), isNull);
  });

  test('1.16.0: "hangi olta ile … 19.00 dan sonra" ekipman önerisi + akşam ipucu', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    await b.yanitla('LRF');
    final y = await b.yanitla('bu mera da sence hangi olta ile daha güzel av olur 19.00 dan sonra');
    expect(y.niyet, startsWith('ekipman'));
    expect(y.metin, contains('Akşam ve gece'));
  });

  test('1.17.0: "sordum" Ordu merası sayılmaz; "yarın" yarının tahminini verir', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final y1 = await b.yanitla('bunu sordum');
    expect(y1.metin, isNot(contains('Ordu')));
    // kelime ortasındaki mera adı eşleşmez (eskiden "sordum" → Ordu gibi)
    expect((await KiyidabiriBeyin(SahteVeri()).yanitla('bekartal qq')).metin, isNot(contains('📍 Kartal')));
    final y2 = await b.yanitla('Kartal yarın nasıl');
    expect(y2.metin, contains('Kartal'));
    expect(y2.metin, contains('Yarın (7.11)'));
    expect(y2.metin, contains('Rüzgâr en çok 28 km/s KD'));
    expect(y2.metin, contains('yağış ihtimali %60'));
    // ardından yalnız gün: son meranın o günü
    final y3 = await b.yanitla('peki yarın?');
    expect(y3.metin, contains('Kartal'));
    expect(y3.metin, contains('Yarın'));
    final y4 = await b.yanitla('bunu sormadım');
    expect(y4.niyet, 'yanlis_anlama');
  });

  test('1.17.0: serbest sohbette ekli yer adı haritada bulunur', () async {
    final y = await KiyidabiriBeyin(SahteVeri()).yanitla('Bugün diliskelesindeyim');
    expect(y.niyet, 'mera');
    expect(y.metin, contains('Diliskelesi, Dilovası'));
  });

  test('1.17.0: gün tespiti', () {
    final per = DateTime(2026, 11, 12); // perşembe
    expect(kbGun('yarin', per), 1);
    expect(kbGun('obur gun nasil', per), 2);
    expect(kbGun('cumartesi kartal', per), 2);
    expect(kbGun('cuma gunu', per), 1);
    expect(kbGun('hafta sonu', per), 2);
    expect(kbGun('kartal nasil', per), isNull);
    expect(kbSadeceGun('peki yarin'), isTrue);
    expect(kbSadeceGun('kartal yarin'), isFalse);
  });

  test('1.16.0: kargo 199 TL, yarısı bizden', () async {
    final y = await KiyidabiriBeyin(SahteVeri()).yanitla('kargo ücreti ne kadar');
    expect(y.metin, contains('199 TL'));
    expect(y.metin, contains('yarısı bizden'));
  });

  test('nokta meran tanınır', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final y = await b.yanitla('gizli koy');
    expect(y.metin, contains('Gizli koy'));
    expect(y.metin, contains('nokta meran'));
  });

  test('topluluk merası önereniyle', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final y = await b.yanitla('sapanca kurtköy');
    expect(y.metin, contains('Bu mera Ali Yılmaz tarafından önerildi'));
  });

  test('bilinmeyen soru → temsilci → WhatsApp', () async {
    final b = KiyidabiriBeyin(SahteVeri())..adim = KbAdim.serbest;
    final y = await b.yanitla('uzaydan balık tutulur mu acaba qwerty');
    expect(y.metin, contains('Müşteri temsilcisine bağlanmak ister misiniz?'));
    final e = await b.yanitla('evet');
    expect(e.secenekler.single.eylem, KbEylem.whatsapp);
  });

  test('sipariş soruları doğrudan temsilciye', () async {
    final b = KiyidabiriBeyin(SahteVeri())..adim = KbAdim.serbest;
    final y = await b.yanitla('siparişim nerede');
    expect(y.niyet, 'siparis');
  });

  test('balık bilgisi uygulama verisinden', () async {
    final b = KiyidabiriBeyin(SahteVeri())..adim = KbAdim.serbest;
    final y = await b.yanitla('levrek nasıl tutulur');
    expect(y.metin, contains('25 cm'));
  });

  test('yemli çinekop: mantarlı takım + çizim + tekne talebi', () async {
    final v = SahteVeri();
    final b = KiyidabiriBeyin(v)..adim = KbAdim.serbest;
    final y = await b.yanitla('yemli çinekop avı nasıl yapılır');
    expect(y.niyet, 'cinekop');
    expect(y.gorsel, KbGorsel.mantarliTakim);
    expect(y.metin, contains('fileto hamsi'));
    expect(y.metin, contains('Tekne avına çıkmak ister misiniz?'));
    expect(y.secenekler.any((s) => s.eylem == KbEylem.whatsapp), isTrue);
    expect((await b.yanitla('evet')).metin, contains('Kaç kişisiniz?'));
    expect((await b.yanitla('3')).metin, contains('Adınız ve soyadınız?'));
    expect((await b.yanitla('Ali')).niyet, 'tekne_ad'); // soyadı eksik
    expect((await b.yanitla('Ali Yılmaz')).niyet, 'tekne_tel');
    expect((await b.yanitla('12345')).girdiGizli, isTrue);
    final son = await b.yanitla('0532 123 45 67');
    expect(son.niyet, 'tekne_talep');
    expect(son.girdiGizli, isTrue);
    expect(v.talepler.single, containsPair('telefon', '05321234567'));
    expect(v.talepler.single, containsPair('kisi', '3'));
  });

  test('lüfer sorusu da mantarlı takıma gider (mera adımında bile)', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    expect((await b.yanitla('yemli lüfer çinekop avı')).niyet, 'cinekop');
  });

  test('bilinmeyen soru önce blogda aranır', () async {
    final b = KiyidabiriBeyin(SahteVeri())..adim = KbAdim.serbest;
    final y = await b.yanitla('amatör belgesi nereden alınır');
    expect(y.niyet, 'blog');
    expect(y.metin, contains('Amatör Balıkçı Belgesi'));
    expect(y.secenekler.first.eylem, KbEylem.blogAc);
  });

  test('öneri JSON ve "önerildi" yazısı', () {
    final o = MeraOnerisi.fromJson({'id': 3, 'tur': 'tuzlu', 'ad': 'Kireçburnu', 'lat': 41.15, 'lon': 29.05, 'baliklar': ['Levrek'], 'oneren': null});
    expect(o.onerenYazisi, isNull);
    expect(o.spot.nokta, isTrue);
    final o2 = MeraOnerisi.fromJson({'id': 4, 'tur': 'tatli', 'ad': 'X Göleti', 'lat': 40, 'lon': 30, 'oneren': 'Ayşe Kaya'});
    expect(o2.onerenYazisi, 'Bu mera Ayşe Kaya tarafından önerildi');
  });
}
