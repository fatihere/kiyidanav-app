import 'dart:math' as math;

/// Gelgit / su seviyesi kartı (panel → Modüller → Su seviyesi): bugünün en düşük, en yüksek ve ortalama seviyesi,
/// şu anki durum ve seçilen balığa göre yorum + ekipman önerisi. Veri: Open-Meteo deniz modeli (sea_level_height_msl).
class GelgitOzet {
  final DateTime enDusukSaat;
  final double enDusukCm; // gün ortalamasına göre (cm)
  final DateTime enYuksekSaat;
  final double enYuksekCm;
  final double simdiCm;
  final bool yukseliyor;
  final String seviye; // düşük | ortalama | yüksek
  final double farkCm; // gün içi en yüksek − en düşük
  final List<double?> seri; // 00:00–24:00 saatlik (ortalamaya göre cm)
  final DateTime gun;

  const GelgitOzet({
    required this.enDusukSaat,
    required this.enDusukCm,
    required this.enYuksekSaat,
    required this.enYuksekCm,
    required this.simdiCm,
    required this.yukseliyor,
    required this.seviye,
    required this.farkCm,
    required this.seri,
    required this.gun,
  });

  /// Gün içi fark bu kadar küçükse seviye değişimi balık davranışında belirleyici değildir
  bool belirsiz(double esikCm) => farkCm < esikCm;
}

/// Saatlik seviye (m) dizisinden bugünün özeti; yetersiz veride null
GelgitOzet? gelgitOzet(List<DateTime> zaman, List<double?> seviyeM, DateTime simdi) {
  final gun = DateTime(simdi.year, simdi.month, simdi.day);
  final seri = <double?>[];
  final saatler = <DateTime>[];
  for (var h = 0; h <= 24; h++) {
    final t = gun.add(Duration(hours: h));
    final i = zaman.indexWhere((z) => z.year == t.year && z.month == t.month && z.day == t.day && z.hour == t.hour);
    seri.add(i < 0 || i >= seviyeM.length ? null : seviyeM[i]);
    saatler.add(t);
  }
  final dolu = seri.whereType<double>().toList();
  if (dolu.length < 12) return null;
  final ort = dolu.reduce((a, b) => a + b) / dolu.length;
  final cm = [for (final v in seri) v == null ? null : (v - ort) * 100];
  var iMin = -1, iMax = -1;
  for (var i = 0; i < cm.length; i++) {
    final v = cm[i];
    if (v == null) continue;
    if (iMin < 0 || v < cm[iMin]!) iMin = i;
    if (iMax < 0 || v > cm[iMax]!) iMax = i;
  }
  final h = simdi.hour.clamp(0, 23);
  double? simdiDeger(int i) {
    for (var k = 0; k < 3; k++) {
      if (i - k >= 0 && cm[i - k] != null) return cm[i - k];
      if (i + k < cm.length && cm[i + k] != null) return cm[i + k];
    }
    return null;
  }

  final s = simdiDeger(h) ?? 0;
  // Saat içindeki konum: bu saat ile sonraki saat arasında doğrusal
  final sonraki = simdiDeger(math.min(24, h + 1)) ?? s;
  final simdiCm = s + (sonraki - s) * (simdi.minute / 60);
  final fark = cm[iMax]! - cm[iMin]!;
  final ucte = fark / 3;
  final seviye = simdiCm < cm[iMin]! + ucte ? 'düşük' : (simdiCm > cm[iMax]! - ucte ? 'yüksek' : 'ortalama');
  return GelgitOzet(
    enDusukSaat: saatler[iMin],
    enDusukCm: cm[iMin]!,
    enYuksekSaat: saatler[iMax],
    enYuksekCm: cm[iMax]!,
    simdiCm: simdiCm,
    yukseliyor: sonraki >= s,
    seviye: seviye,
    farkCm: fark,
    seri: cm,
    gun: gun,
  );
}

/// Kartta seçilen hedef balık
class GelgitTur {
  final String ad;
  final String davranis; // su seviyesi / akıntı ile ilişkisi
  final String donem; // avlanma dönemi ve göç (İstanbul)
  final String ekipman;
  final String ara; // uygulamada ürün araması
  const GelgitTur(this.ad, this.davranis, this.donem, this.ekipman, this.ara);

  factory GelgitTur.fromJson(Map<String, dynamic> j) => GelgitTur(
        '${j['tur'] ?? j['ad'] ?? ''}'.trim(),
        '${j['davranis'] ?? j['metin'] ?? ''}'.trim(),
        '${j['donem'] ?? ''}'.trim(),
        '${j['ekipman'] ?? ''}'.trim(),
        '${j['ara'] ?? j['tur'] ?? ''}'.trim(),
      );
}

/// İstanbul kıyıları için varsayılan liste (panelde "turler" ile değiştirilebilir/eklenebilir)
const gelgitTurleri = <GelgitTur>[
  GelgitTur('Palamut', 'Palamut su seviyesinden çok akıntıya ve yem sürüsüne bakar; akıntının döndüğü, suyun hareketlendiği saatlerde Boğaz burunlarında yüzeye vurur.',
      'Ağustos sonu–Aralık; Karadeniz\'den Marmara\'ya göçte Boğaz\'da en yoğun Eylül–Kasım. Asgari boy 25 cm.',
      '2,4–2,7 m spin kamış, 20–40 g kaşık ya da jig, palamut çaparisi', 'palamut'),
  GelgitTur('Eşkina', 'Yükselen suda kayalık ceplere ve mendirek diplerine yaklaşır; karanlıkta yemlenir.',
      'Mayıs–Ekim, en verimli gece ve karanlık saatler; kayalık oyuklarda yerleşik. Asgari boy 35 cm.',
      'Dip ya da şamandıra takımı, 1/0–2 numara iğne, karides veya yengeç', 'dip takımı'),
  GelgitTur('Mırmır', 'Kumluk kıyıda yükselen su ve hafif dalga mırmırı kıyıya getirir; dalganın kumu eşelediği şeritte yemlenir.',
      'Mayıs–Ekim; İstanbul\'da en verimli Eylül–Ekim, Karadeniz ve Marmara kumsalları.',
      'Surf casting takımı, ince köstek, boru kurdu ya da mamun', 'surf casting'),
  GelgitTur('Çinekop', 'Çinekop akıntılı burunlarda yem balığı sürülerini kovalar; su hareketlendiğinde ve alacakaranlıkta en aktiftir.',
      'Eylül–Kasım; lüferin küçüğüdür, Boğaz iskeleleri ve mendireklerde. Lüfer için asgari boy 18 cm — küçükleri denize bırak.',
      'Hafif spin ya da LRF, 5–15 g kaşık, çinekop çaparisi, küçük maket', 'çinekop çapari'),
  GelgitTur('Sarıkanat', 'Sarıkanat akıntının döndüğü saatlerde ve alacakaranlıkta derin burunlara yaklaşır.',
      'Ekim–Aralık; Karadeniz\'den inen sürülerle Boğaz ve Marmara girişinde.',
      'Spin kamış, 20–30 g kaşık, rapala, çelik tel köstek', 'rapala'),
  GelgitTur('Lüfer', 'Akıntının döndüğü saatler lüfer için en hareketli zamandır; gece ve alacakaranlıkta burunlarda dolaşır.',
      'Eylül–Aralık (Boğaz\'da en verimli Ekim–Kasım); sonbahar göçüyle Karadeniz\'den Marmara\'ya iner. Asgari boy 18 cm.',
      'Spin takımı, kaşık ve rapala, çelik tel köstek; canlı istavrit', 'lüfer kaşık'),
  GelgitTur('Levrek', 'Düşük suda levrek kayalık dibindeki ceplerde ve dere ağızlarında av arar; alçalırken su kenara yem süpürür.',
      'Ekim–Nisan, soğuk ve dalgalı havada en verimli. Asgari boy 25 cm.',
      'Maket balık (9–14 cm), silikon, 2,7–3 m spin kamış', 'levrek maket'),
  GelgitTur('İstavrit', 'Su seviyesinden çok ışık ve akıntıya bakar; akşam mendirek ışığı altında toplanır.',
      'Tüm yıl; en bol Eylül–Mart. Asgari boy 13 cm.',
      'Çapari, 1–3 g LRF jighead + silikon, LRF kamış', 'istavrit çapari'),
  GelgitTur('İskorpit', 'Kayalık dipte saklanır; yükselen suda kaya aralarından çıkıp yem arar.',
      'Tüm yıl, gece daha verimli; mendirek taşları ve kayalık dipler. Dikenleri zehirlidir, dikkatli tut.',
      'LRF (dipten, texas) ya da dip takımı; silikon veya karides', 'lrf silikon'),
  GelgitTur('Kalkan', 'Kumluk dipte gömülü bekler; akıntı ve su hareketi yem balığını getirdiğinde beslenir.',
      'Karadeniz kıyısında (Kilyos, Rumelifeneri) kumlu dipler; en verimli Mart–Mayıs. 15 Nisan–15 Haziran Karadeniz\'de av yasağı, asgari boy 45 cm.',
      'Ağır dip / surf takımı, 100–150 g kurşun, istavrit ya da hamsi yem', 'dip takımı'),
];

/// Kart metni: seviye + yön + seçilen balığa göre yorum
String gelgitYorum(GelgitOzet o, String mera, {double esikCm = 10}) {
  if (o.belirsiz(esikCm)) {
    return 'Bugün $mera\'da su seviyesi belirgin değişmiyor (gün içi fark ${o.farkCm.round()} cm); balığı asıl rüzgâr, akıntı ve basınç yönlendirir.';
  }
  final yon = o.yukseliyor ? 'yükseliyor' : 'alçalıyor';
  final ek = o.seviye == 'düşük'
      ? ' Düşük su özellikle büyük balık avında avantaj yaratır: balık kayalık ceplerde ve kanallarda toplanır.'
      : (o.seviye == 'yüksek' ? ' Yüksek suda balık sığa ve kıyıya yaklaşır; yakın atışları dene.' : '');
  return 'Kıyı avcılığında bugün gelgit ${o.seviye} seviyede ve $yon.$ek';
}
