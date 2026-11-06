import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/freshwater.dart';
import 'package:kiyidanav/kiyidabiri_beyin.dart';
import 'package:kiyidanav/mera.dart';
import 'package:kiyidanav/mera_oner.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/sea.dart';

/// Ağsız sahte veri: Kartal sakin, Riva dalgalı (surf için ideal), Beykoz Boğaz içi
class SahteVeri implements KbVeri {
  final pin = Spot.pin(40.9, 29.2, spots.firstWhere((s) => s.name == 'Kartal'), ad: 'Gizli koy');
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
      ]);
  @override
  Future<List<SpotForecast>> simdi(List<Spot> l) async => [for (final s in l) SpotForecast(spot: s, now: _r(s))];
  @override
  Future<MeraInfo?> kesit(Spot s) async =>
      const MeraInfo(dip: 'Kaya → kum', profile: [MapEntry(50, 4.0), MapEntry(100, 9.0)], note: 'Akşamüstü levrek');
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

  test('akış: mera → stil → kampanya', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final y1 = await b.yanitla('Bugün kartaldayım');
    expect(y1.niyet, 'mera');
    expect(y1.metin, contains('Kartal'));
    expect(y1.metin, contains('av verimliliği'));
    expect(y1.metin, contains('Dip yapısı: Kaya → kum'));
    expect(y1.metin, contains('Hangi stilde avlanıyorsun?'));
    expect(b.adim, KbAdim.stil);

    final y2 = await b.yanitla('surf');
    expect(y2.metin, contains('Surf için'));
    // Dalgası surf'e en uygun olan Riva önerilmeli (Boğaz içi değil)
    expect(y2.metin, contains('en uygun mera: Riva'));
    expect(y2.metin, contains('Hangi üründe kampanya istersin?'));

    final y3 = await b.yanitla('Olta makinesi');
    expect(y3.kampanya, 'Olta makinesi');
    expect(y3.metin, contains('Shimano Sienna 2500'));
    expect(b.adim, KbAdim.serbest);
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

  test('öneri JSON ve "önerildi" yazısı', () {
    final o = MeraOnerisi.fromJson({'id': 3, 'tur': 'tuzlu', 'ad': 'Kireçburnu', 'lat': 41.15, 'lon': 29.05, 'baliklar': ['Levrek'], 'oneren': null});
    expect(o.onerenYazisi, isNull);
    expect(o.spot.nokta, isTrue);
    final o2 = MeraOnerisi.fromJson({'id': 4, 'tur': 'tatli', 'ad': 'X Göleti', 'lat': 40, 'lon': 30, 'oneren': 'Ayşe Kaya'});
    expect(o2.onerenYazisi, 'Bu mera Ayşe Kaya tarafından önerildi');
  });
}
