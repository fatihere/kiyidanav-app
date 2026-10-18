/// Bölgelere göre kıyıdan av veren balıklar, yasal asgari boy ve limitler, avlanma teknikleri.
/// Boy ve limitler: 6/2 Numaralı Amatör Amaçlı Su Ürünleri Avcılığının Düzenlenmesi Hakkında Tebliğ (2024–2028), Çizelge 7.
/// Saf Dart; kıyı yönleri ve bölge eşleşmesi de buradadır.
library;

import 'moduller.dart';
import 'sea.dart';

class BalikBilgi {
  final String ad;
  final String boy; // asgari boy
  final String limit;
  final String teknik;
  final List<int> aylar; // en verimli aylar
  final int mesafeMin, mesafeMax; // kıyıdan tipik mesafe (m)
  final (int, int, int, int)? yasak; // (ay, gün) – (ay, gün)
  final String not;
  const BalikBilgi(this.ad, this.boy, this.limit, this.teknik, this.aylar, this.mesafeMin, this.mesafeMax,
      {this.yasak, this.not = ''});

  bool sezonda(int ay) => aylar.contains(ay);

  bool yasakta(DateTime t) {
    final y = yasak;
    if (y == null) return false;
    final g = t.month * 100 + t.day;
    return g >= y.$1 * 100 + y.$2 && g <= y.$3 * 100 + y.$4;
  }

  String get yasakMetni {
    final y = yasak;
    if (y == null) return '';
    const ay = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${y.$2} ${ay[y.$1]} – ${y.$4} ${ay[y.$3]}';
  }
}

const _hepsi = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

const baliklar = <String, BalikBilgi>{
  'levrek': BalikBilgi('Levrek', '25 cm', '5 kg toplam', 'Spin (rapala, silikon 10–30 g); dalgalı havada köpük hattı, surf\'te canlı yem', [1, 2, 3, 10, 11, 12], 5, 40),
  'cupra': BalikBilgi('Çipura (Çupra)', '20 cm', '5 kg toplam', 'Dip / surf; yengeç, midye, boru kurdu; kum–kaya geçişi', [5, 6, 7, 8, 9, 10, 11], 8, 60,
),
  'lidaki': BalikBilgi('Lidaki (çipura yavrusu)', 'Çipura asgari boyu 20 cm', 'Boyu tutmayan suya iade',
      'LRF / hafif dip, 2–6 g; midye, boru kurdu, karides; iskele dibi ve kum–kaya geçişi', [6, 7, 8, 9, 10, 11], 3, 30,
      not: '200 g altı çipura: 30–50 g ince lidaki, ~100 g lidaki, 100–180 g kaba lidaki. Çoğu yasal boyun altındadır.'),
  'lufer': BalikBilgi('Lüfer / Çinekop', '18 cm', '5 kg toplam', 'Spin, kaşık 20–40 g, zoka; akıntılı burunlar', [9, 10, 11, 12], 20, 90),
  'sargoz': BalikBilgi('Sargoz', '21 cm', '5 kg toplam', 'LRF / hafif dip; midye, karides, boru kurdu; kayalık dibi', [1, 2, 3, 4, 10, 11, 12], 2, 25),
  'karagoz': BalikBilgi('Karagöz', '18 cm', '5 kg toplam', 'LRF, şamandıra; gece kayalık kenarı, karides', [1, 2, 3, 4, 5, 9, 10, 11, 12], 2, 20),
  'mirmir': BalikBilgi('Mırmır', 'Tebliğde boy sınırı yok', '5 kg toplam', 'Surf / dip; kum zeminde gece, boru kurdu, mamun', [5, 6, 7, 8, 9, 10], 5, 40),
  'minekop': BalikBilgi('Minekop (Kötek, Karakulak)', '45 cm', '5 kg toplam', 'Surf / dip; gece, yengeç ve canlı karides; kum–kaya', [6, 7, 8, 9, 10], 10, 60),
  'eskina': BalikBilgi('Eşkina', '35 cm', '3 adet', 'LRF / dip; gece kaya oyukları, canlı karides', [4, 5, 6, 7, 8, 9, 10], 2, 20),
  'istavrit': BalikBilgi('İstavrit', '13 cm', '5 kg toplam', 'Çapari, LRF 1–5 g; ışıklı alanlar', _hepsi, 5, 40),
  'palamut': BalikBilgi('Palamut', '25 cm', '5 kg toplam', 'Spin, kaşık 30–50 g; sabah ve akşam', [8, 9, 10, 11], 30, 100, yasak: (4, 1, 8, 14)),
  'kefal': BalikBilgi('Kefal', 'Has / sarıkulak 30 cm · diğer 20 cm', '5 kg toplam', 'Şamandıra, ekmek / hamur yem', _hepsi, 2, 20),
  'mezgit': BalikBilgi('Mezgit', '13 cm', '5 kg toplam', 'Dip; derin kıyılarda kurşun arkası', [1, 2, 3, 4, 11, 12], 30, 120),
  'kalkan': BalikBilgi('Kalkan', '45 cm', '1 adet', 'Surf; kum zemin, canlı istavrit', [2, 3, 9, 10, 11, 12], 40, 150, yasak: (4, 15, 6, 15)),
  'barbunya': BalikBilgi('Barbunya', '12 cm', '5 kg toplam', 'Dip; kum–çamur, boru kurdu', [1, 2, 3, 4, 9, 10, 11, 12], 20, 80),
  'zargana': BalikBilgi('Zargana', 'Tebliğde boy sınırı yok', '5 kg toplam', 'Şamandıra, LRF yüzey; ince iğne', [4, 5, 6, 7, 8, 9, 10], 5, 40),
  'kolyoz': BalikBilgi('Kolyoz', '18 cm', '5 kg toplam', 'Çapari, küçük kaşık', [6, 7, 8, 9, 10], 10, 60),
  'isparoz': BalikBilgi('İsparoz', 'Tebliğde boy sınırı yok', '5 kg toplam', 'LRF / hafif dip; midye', [5, 6, 7, 8, 9, 10, 11], 2, 25),
  'izmarit': BalikBilgi('İzmarit', 'Tebliğde boy sınırı yok', '5 kg toplam', 'LRF; ekmek, karides', [4, 5, 6, 7, 8, 9, 10, 11], 2, 25),
  'mercan': BalikBilgi('Mercan (Kırma)', '15 cm', '5 kg toplam', 'Dip; karides, kalamar', [5, 6, 7, 8, 9, 10, 11], 10, 60),
  'akya': BalikBilgi('Akya', '40 cm', '1 adet', 'Canlı yem, spin (popper, rapala)', [9, 10, 11], 20, 80, yasak: (4, 15, 5, 15)),
  'sinarit': BalikBilgi('Sinarit (Sinagrit)', '35 cm', '5 kg toplam', 'Canlı yem, kalamar; derin kaya', [1, 2, 3, 4, 10, 11, 12], 30, 100),
  'dil': BalikBilgi('Dil', '20 cm', '5 kg toplam', 'Dip; kum zemin, boru kurdu', [3, 4, 5, 6, 7, 8, 9, 10], 20, 80, yasak: (1, 1, 2, 15)),
  'sarikuyruk': BalikBilgi('Sarıkuyruk (Avcı)', '30 cm', '1 adet', 'Spin (popper, jig), canlı yem', [8, 9, 10, 11], 20, 100, yasak: (4, 15, 5, 15)),
  'iskorpit': BalikBilgi('İskorpit', 'Tebliğde boy sınırı yok', '5 kg toplam', 'LRF; kaya diplerinde, dikenlerine dikkat', _hepsi, 2, 15),
  'kirlangic': BalikBilgi('Kırlangıç', '18 cm', '5 kg toplam', 'Dip; kum zemin', [1, 2, 3, 4, 10, 11, 12], 20, 80),
};

/// Kıyıdan av ihtimali: bölge → tür → yaygınlık (3 çok yaygın, 2 sık, 1 ara sıra).
/// Listede olmayan tür o bölgede kıyıdan beklenmez (ör. Kartal'da çupra, sargoz, karagöz yok).
const bolgeAgirlik = <String, Map<String, int>>{
  'Doğu Karadeniz': {'istavrit': 3, 'mezgit': 3, 'kefal': 3, 'barbunya': 2, 'palamut': 2, 'zargana': 2, 'iskorpit': 2,
    'kalkan': 1, 'lufer': 1, 'levrek': 1, 'kolyoz': 1},
  'Batı Karadeniz': {'istavrit': 3, 'lufer': 3, 'palamut': 3, 'kefal': 3, 'levrek': 2, 'mezgit': 2, 'barbunya': 2,
    'kolyoz': 2, 'zargana': 2, 'iskorpit': 2, 'kalkan': 1, 'karagoz': 1, 'minekop': 1, 'eskina': 1},
  'İstanbul': {'istavrit': 3, 'lufer': 3, 'kefal': 3, 'palamut': 2, 'levrek': 2, 'mezgit': 2, 'zargana': 2, 'kolyoz': 2,
    'izmarit': 2, 'iskorpit': 2, 'barbunya': 1, 'kirlangic': 1},
  'Trakya Marmara': {'istavrit': 3, 'kefal': 3, 'levrek': 2, 'lufer': 2, 'palamut': 2, 'mezgit': 2, 'kolyoz': 2,
    'zargana': 2, 'izmarit': 2, 'barbunya': 1, 'kalkan': 1, 'dil': 1},
  'Marmara': {'istavrit': 3, 'kefal': 3, 'levrek': 2, 'lufer': 2, 'palamut': 2, 'kolyoz': 2, 'mezgit': 2, 'izmarit': 2,
    'isparoz': 1, 'barbunya': 1},
  'Kuzey Ege (Enez–Çanakkale)': {'cupra': 3, 'lidaki': 3, 'kefal': 3, 'levrek': 2, 'sargoz': 2, 'karagoz': 2, 'mirmir': 2,
    'istavrit': 2, 'lufer': 2, 'zargana': 2, 'isparoz': 2, 'mercan': 1, 'eskina': 1, 'minekop': 1, 'dil': 1, 'kalkan': 1,
    'kirlangic': 1},
  'Ege': {'cupra': 3, 'lidaki': 3, 'sargoz': 3, 'izmarit': 3, 'kefal': 3, 'karagoz': 2, 'mirmir': 2, 'isparoz': 2,
    'levrek': 2, 'mercan': 2, 'istavrit': 2, 'iskorpit': 2, 'kolyoz': 2, 'eskina': 1, 'minekop': 1, 'akya': 1, 'lufer': 1,
    'sinarit': 1, 'barbunya': 1},
  'Güney Ege': {'cupra': 3, 'sargoz': 3, 'izmarit': 3, 'lidaki': 2, 'karagoz': 2, 'mirmir': 2, 'isparoz': 2, 'mercan': 2,
    'kefal': 2, 'akya': 2, 'iskorpit': 2, 'kolyoz': 2, 'levrek': 1, 'sarikuyruk': 1, 'eskina': 1, 'sinarit': 1},
  'Akdeniz': {'sargoz': 3, 'izmarit': 3, 'kefal': 3, 'cupra': 2, 'karagoz': 2, 'mirmir': 2, 'isparoz': 2, 'mercan': 2,
    'akya': 2, 'iskorpit': 2, 'istavrit': 2, 'levrek': 1, 'sarikuyruk': 1, 'barbunya': 1, 'kolyoz': 1},
};

const _kuzeyEge = {'Enez', 'Saros', 'Gelibolu', 'Eceabat', 'Lapseki', 'Çanakkale', 'Babakale', 'Assos', 'Küçükkuyu'};

/// Meranın balık bölgesi
String balikBolgesi(Spot s) {
  final ad = s.key;
  if (_kuzeyEge.contains(ad)) return 'Kuzey Ege (Enez–Çanakkale)';
  switch (s.side) {
    case Side.anadolu:
    case Side.avrupa:
      return 'İstanbul';
    case Side.karadeniz:
      return s.lon > 34.5 ? 'Doğu Karadeniz' : 'Batı Karadeniz';
    case Side.izmit:
    case Side.guneyMarmara:
      return 'Marmara';
    case Side.trakya:
      return 'Trakya Marmara';
    case Side.ege:
      return 'Ege';
    case Side.guneyEge:
      return 'Güney Ege';
    case Side.akdeniz:
      return 'Akdeniz';
  }
}

/// Bugünkü av ihtimali puanı: bölgedeki yaygınlık × sezon; av yasağındaki tür en alta düşer
double avIhtimali(String bolge, String tur, DateTime now) {
  final w = bolgeAgirlik[bolge]?[tur] ?? 0;
  final b = baliklar[tur];
  if (w == 0 || b == null) return 0;
  if (b.yasakta(now)) return 0.1;
  return w * (b.sezonda(now.month) ? 1.0 : 0.3);
}

/// Bölgedeki türler, bugün en olası olandan başlayarak
List<String> bolgeTurleri(Spot s, [DateTime? zaman]) {
  final now = zaman ?? DateTime.now();
  final bolge = balikBolgesi(s);
  final l = (bolgeAgirlik[bolge]?.keys ?? const <String>[]).where(baliklar.containsKey).toList();
  l.sort((a, b) => avIhtimali(bolge, b, now).compareTo(avIhtimali(bolge, a, now)));
  return l;
}

/// Kıyının denize baktığı yön (°). Panelde (Modüller → Rüzgâr ve kıyı) girilen değer önceliklidir.
double? kiyiYonu(Spot s) {
  final m = Moduller.ham('kiyi_yonu');
  if (m != null) {
    for (final e in m.l('meralar')) {
      if ('${e['mera'] ?? ''}'.trim().toLowerCase() == s.key.toLowerCase()) {
        final v = e['yon'];
        final d = v is num ? v.toDouble() : double.tryParse('$v');
        if (d != null) return d;
      }
    }
  }
  return varsayilanKiyiYonu[s.key]?.toDouble();
}

/// Yaklaşık kıyı yönleri (kıyıdan denize bakış, derece). Panelde düzeltilebilir.
const varsayilanKiyiYonu = <String, int>{
  'Riva': 10, 'Beykoz': 270, 'Üsküdar': 270, 'Moda': 225, 'Maltepe': 200, 'Kartal': 200, 'Pendik': 200, 'Tuzla': 200, 'Darıca': 180,
  'Rumelifeneri': 45, 'Garipçe': 100, 'Sarıyer': 90, 'Bebek': 90, 'Karaköy': 150, 'Yenikapı': 180, 'Bakırköy': 180, 'Florya': 180,
  'Avcılar': 180, 'Büyükçekmece': 180, 'Semizkum': 180,
  'İğneada': 90, 'Kıyıköy': 70, 'Yalıköy': 45, 'Karaburun': 20, 'Kilyos': 0, 'Şile': 0, 'Kefken': 0, 'Karasu': 0, 'Akçakoca': 0,
  'Zonguldak': 330, 'Amasra': 330, 'Cide': 0, 'İnebolu': 0, 'Sinop': 120, 'Samsun': 30, 'Ünye': 0, 'Ordu': 10, 'Giresun': 20,
  'Trabzon': 0, 'Rize': 0, 'Hopa': 330, 'Kemalpaşa': 330,
  'Eskihisar': 180, 'Hereke': 180, 'İzmit': 180, 'Gölcük': 0, 'Karamürsel': 0, 'Dereköy': 0,
  'Silivri': 180, 'Gümüşyaka': 180, 'Marmaraereğlisi': 180, 'Tekirdağ': 160, 'Kumbağ': 150, 'Mürefte': 150, 'Şarköy': 150,
  'Gelibolu': 120, 'Eceabat': 100, 'Saros': 180, 'Enez': 200,
  'Altınova': 0, 'Yalova': 0, 'Armutlu': 0, 'Gemlik': 270, 'Mudanya': 0, 'Bandırma': 0, 'Erdek': 270, 'Karabiga': 0,
  'Lapseki': 300, 'Çanakkale': 300, 'Babakale': 230, 'Assos': 180, 'Küçükkuyu': 180,
  'Akçay': 200, 'Ayvalık': 270, 'Dikili': 270, 'Çandarlı': 240, 'Foça': 270, 'Karşıyaka': 180, 'Urla': 0, 'Çeşme': 270,
  'Sığacık': 225, 'Pamucak': 270,
  'Kuşadası': 270, 'Didim': 225, 'Güllük': 220, 'Turgutreis': 270, 'Bodrum': 180, 'Akyaka': 250, 'Datça': 180, 'Marmaris': 180,
  'Sarıgerme': 180, 'Fethiye': 330, 'Kalkan': 200, 'Kaş': 180, 'Finike': 160, 'Kemer': 90, 'Konyaaltı': 150, 'Lara': 180,
  'Side': 200, 'Alanya': 180, 'Gazipaşa': 210, 'Anamur': 180, 'Taşucu': 180, 'Erdemli': 150, 'Mersin': 160, 'Karataş': 180,
  'Yumurtalık': 180, 'İskenderun': 300, 'Arsuz': 270, 'Samandağ': 250,
};
