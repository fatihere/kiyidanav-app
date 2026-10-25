/// Mera kartındaki ölçümlerin (basınç, dalga periyodu, bulut, uydu verileri…) balıkçı diliyle yorumu.
///
/// Amaç: kıyıdan 2–200 m aralığında balığın NEREDE olduğunu söylemek.
///   LRF: 2–20 m · Spin / maket / jig: 10–50 m · Surf, çapari, kurşun arkası: 10–200 m
///
/// Saf Dart'tır (Flutter yok), böylece birim testleriyle doğrulanır. Aynı kurallar
/// web sitesindeki "Mera Bilgisi" sayfasında (mera-bilgisi.php) JavaScript ile birebir uygulanır.
library;

/// 0 = olumlu (yeşil), 1 = orta (sarı), 2 = zayıf/dikkat (kırmızı)
enum Ton { iyi, orta, zayif }

class OlcumYorum {
  /// Sayfa başlığı (ör. "Basınç")
  final String baslik;

  /// Ekrandaki değer (ör. "1015 hPa ↘")
  final String deger;

  /// Kısa hüküm (ör. "Düşüyor: balık kıyıya yakın")
  final String durum;
  final Ton ton;

  /// Önerilen atış mesafesi ve disiplin (boş olabilir)
  final String mesafe;

  /// Ne anlama geldiği — 2-4 kısa madde
  final List<String> maddeler;

  /// Genel kural tablosu: (aralık, anlamı). [aktif] o anki satırın sırası (yoksa -1).
  final List<(String, String)> kurallar;
  final int aktif;

  /// Kaynak / uyarı notu
  final String not;

  const OlcumYorum({
    required this.baslik,
    required this.deger,
    required this.durum,
    this.ton = Ton.orta,
    this.mesafe = '',
    this.maddeler = const [],
    this.kurallar = const [],
    this.aktif = -1,
    this.not = '',
  });
}

/// Mesafe bantları (kıyıdan atış)
class Mesafe {
  static const yakin = 'Yakın: 2–40 m · LRF ve kıyı dibi spin (kaya dibi, iskele ayağı, köpük hattı)';
  static const yakinOrta = 'Yakın–orta: 10–60 m · LRF, spin, maket balık, hafif jig';
  static const orta = 'Orta: 30–100 m · spin/jig uzun atış, çapari, surf kısa atış';
  static const uzak = 'Uzak/derin: 80–200 m · surf casting, kurşun arkası, ağır jig dibe yakın';
}

/// Panelden düzenlenen basınç kuralı ("Eğilim ≤ −2", "Basınç > 1018" …)
class BasincKural {
  final String kosul;
  final String durum;
  final String mesafe;
  final Ton ton;
  final bool egilim; // true: eğilime bakar, false: basınca
  final String op;
  final double deger;
  const BasincKural(this.kosul, this.durum, this.mesafe, this.ton, this.egilim, this.op, this.deger);

  bool uyar(double p, double? t) {
    final v = egilim ? (t ?? 0) : p;
    switch (op) {
      case '<':
        return v < deger;
      case '≤':
        return v <= deger;
      case '>':
        return v > deger;
      default:
        return v >= deger;
    }
  }

  static final _re = RegExp(r'^\s*(eğilim|egilim|basınç|basinc)\s*(<=|>=|≤|≥|<|>)\s*([+\-−]?\s*\d+(?:[.,]\d+)?)', caseSensitive: false);

  /// Panel satırı → kural (anlaşılmazsa null)
  static BasincKural? oku(Map<String, dynamic> r) {
    final k = '${r['kosul'] ?? ''}';
    final m = _re.firstMatch(k.replaceAll('İ', 'i').replaceAll('I', 'ı'));
    if (m == null) return null;
    var op = m.group(2)!;
    if (op == '<=') op = '≤';
    if (op == '>=') op = '≥';
    final d = double.tryParse(m.group(3)!.replaceAll('−', '-').replaceAll(' ', '').replaceAll(',', '.'));
    if (d == null) return null;
    final ms = '${r['mesafe'] ?? ''}';
    final mesafe = ms.startsWith('Yakın–orta') || ms.startsWith('Yakın-orta')
        ? Mesafe.yakinOrta
        : ms.startsWith('Yakın')
            ? Mesafe.yakin
            : ms.startsWith('Orta')
                ? Mesafe.orta
                : ms.startsWith('Uzak')
                    ? Mesafe.uzak
                    : '';
    final tn = '${r['ton'] ?? ''}';
    final ton = tn == 'iyi' ? Ton.iyi : (tn == 'zayıf' || tn == 'zayif' ? Ton.zayif : Ton.orta);
    final eg = m.group(1)!.toLowerCase().startsWith('e');
    return BasincKural(k, '${r['durum'] ?? ''}', mesafe, ton, eg, op, d);
  }
}

String _ok(double? t) => t == null ? '' : (t <= -0.8 ? ' ↘' : (t >= 0.8 ? ' ↗' : ' →'));

class Yorum {
  /// Panel → Modüller → Ölçüm açıklamaları: düzenlenmiş basınç kuralları ve not (boşsa varsayılan)
  static List<BasincKural> ozelBasinc = const [];
  static String ozelNot = '';

  static void panelden(List<Map<String, dynamic>> satirlar, String not) {
    ozelBasinc = satirlar.map(BasincKural.oku).whereType<BasincKural>().toList();
    ozelNot = not.trim();
  }

  static OlcumYorum _ozelBasinc(double p, double? t) {
    final i = ozelBasinc.indexWhere((k) => k.uyar(p, t));
    final k = i < 0 ? null : ozelBasinc[i];
    final degisim = t == null ? '' : ' (6 saatte ${t > 0 ? '+' : ''}${t.toStringAsFixed(1)} hPa)';
    return OlcumYorum(
      baslik: 'Basınç',
      deger: '${p.round()} hPa${_ok(t)}',
      durum: k?.durum ?? 'Olağan',
      ton: k?.ton ?? Ton.orta,
      mesafe: k?.mesafe ?? '',
      maddeler: [
        'Şu an ${p.round()} hPa$degisim.',
        'Balığı en çok basıncın DEĞİŞİMİ etkiler: düşen basınç (hava bozacak) iştahı açar, cephe arkasında yükselen basınç kapatır.',
        'Basınç ile birlikte rüzgâr ve dalgaya bak: hızlı düşüş çoğu zaman birkaç saat sonra sert rüzgâr getirir — güvenli kıyı seç.',
      ],
      kurallar: [for (final x in ozelBasinc) (x.kosul, x.durum)],
      aktif: i,
      not: ozelNot.isNotEmpty ? ozelNot : 'Değer deniz seviyesine indirgenmiş basınçtır.',
    );
  }
  // ---------------------------------------------------------------- Basınç
  /// [p] deniz seviyesine indirgenmiş basınç (hPa), [t] önümüzdeki 6 saatteki değişim (hPa).
  /// Mutlak değerden çok EĞİLİM belirleyicidir; tablo bu yüzden ikisini birlikte kullanır.
  static const basincKurallari = <(String, String)>[
    ('Düşüyor, 6 saatte 2 hPa ve fazlası', 'Cephe yaklaşıyor. Balık iştahlı ve kıyıya yakın — en verimli pencere hava bozmadan önceki saatler. Yakın mesafede dene.'),
    ('Yavaş düşüyor (−0,8 / −2 hPa)', 'Balık hareketli ve sığa yaklaşıyor. Yakın–orta mesafe.'),
    ('1005 altı ve sabit', 'Kapalı, rüzgârlı hava. Balık dağınık; dalgalı, bulanık kıyıda (levrek) yakın mesafe işe yarar.'),
    ('1005–1018 ve sabit', 'Olağan düzen. Şafak ve akşam kıyıya yanaşır, gün içinde orta mesafe.'),
    ('1018 üstü ve sabit', 'Açık, sakin, berrak su. Balık derinde ve temkinli — gün ortası zayıf. Uzun atış, dibe yakın, ince lider; gece LRF.'),
    ('Yükseliyor (+0,8 / +2 hPa)', 'Cephe geçti, hava açılıyor. İlk 12–24 saat balık derine çekilir; ertesi gün toparlanır.'),
    ('Hızlı yükseliyor, 6 saatte 2 hPa ve fazlası', 'Şansın zayıf. Balık derinde ve isteksiz — uzak atış, yavaş sunum, kokulu doğal yem.'),
  ];

  static int basincSatiri(double p, double? t) {
    final d = t ?? 0;
    if (d <= -2) return 0;
    if (d <= -0.8) return 1;
    if (d >= 2) return 6;
    if (d >= 0.8) return 5;
    if (p < 1005) return 2;
    if (p <= 1018) return 3;
    return 4;
  }

  static OlcumYorum basinc(double? p, double? t) {
    if (p == null) {
      return const OlcumYorum(baslik: 'Basınç', deger: '—', durum: 'Basınç verisi alınamadı', kurallar: basincKurallari);
    }
    if (ozelBasinc.isNotEmpty) return _ozelBasinc(p, t);
    final s = basincSatiri(p, t);
    const durumlar = [
      'Hızlı düşüyor: balık kıyıda, yakın dene',
      'Düşüyor: balık sığa yaklaşıyor',
      'Alçak ve sabit: balık dağınık',
      'Normal ve sabit: olağan düzen',
      'Yüksek ve sabit: balık derinde',
      'Yükseliyor: balık derine çekiliyor',
      'Hızlı yükseliyor: şansın zayıf',
    ];
    const tonlar = [Ton.iyi, Ton.iyi, Ton.orta, Ton.orta, Ton.zayif, Ton.zayif, Ton.zayif];
    const mesafeler = [Mesafe.yakin, Mesafe.yakinOrta, Mesafe.yakinOrta, Mesafe.orta, Mesafe.uzak, Mesafe.uzak, Mesafe.uzak];
    final degisim = t == null ? '' : ' (6 saatte ${t > 0 ? '+' : ''}${t.toStringAsFixed(1)} hPa)';
    return OlcumYorum(
      baslik: 'Basınç',
      deger: '${p.round()} hPa${_ok(t)}',
      durum: durumlar[s],
      ton: tonlar[s],
      mesafe: mesafeler[s],
      maddeler: [
        'Şu an ${p.round()} hPa$degisim. ${basincKurallari[s].$2}',
        'Balığı en çok basıncın DEĞİŞİMİ etkiler: düşen basınç (hava bozacak) iştahı açar, cephe arkasında yükselen basınç kapatır.',
        'Basınç ile birlikte rüzgâr ve dalgaya bak: hızlı düşüş çoğu zaman birkaç saat sonra sert rüzgâr getirir — güvenli kıyı seç.',
      ],
      kurallar: basincKurallari,
      aktif: s,
      not: 'Değer deniz seviyesine indirgenmiş basınçtır. Bu kurallar Marmara ve Karadeniz kıyı avcılığındaki yaygın gözleme dayanır; kesin değil, yön göstericidir.',
    );
  }

  // ---------------------------------------------------------------- Dalga periyodu
  static const periyotKurallari = <(String, String)>[
    ('4 sn altı', 'Rüzgâr dalgası (çırpıntı). Yüzey karışık, kıyı dibi köpüklü ve bulanık.'),
    ('4–7 sn', 'Dengeli dalga. Burun ve kayalıklarda köpük hattı oluşur — levrek ve lüfer için iyi.'),
    ('7 sn ve üstü', 'Uzaktan gelen soluğan (swell). Boyu küçük görünse de kıyıda sert kırılır, dibi kazır, yem açığa çıkar.'),
  ];

  static OlcumYorum dalgaPeriyodu(double sn, double? dalgaM) {
    final s = sn < 4 ? 0 : (sn < 7 ? 1 : 2);
    final h = dalgaM ?? 0;
    final tehlike = s == 2 && h >= 1.0;
    final maddeler = <String>[
      periyotKurallari[s].$2,
      if (s == 0) 'Hafif takımla (LRF) kontrol zorlaşır; biraz ağır jighead ya da kurşunlu takım kullan. Köpüklü kıyı dibinde levrek avlanır.',
      if (s == 1) 'Kırılma hattının hemen arkası (20–60 m) en verimli bant. Maket balığı köpüğün içinden geçirerek çek.',
      if (s == 2)
        'Kumsalda surf casting için iyi: dalga dipten kurt, midye, yengeç kaldırır; balık kırılma hattının ötesinde (40–120 m) beslenir.',
      if (tehlike) 'DİKKAT: ${h.toStringAsFixed(1)} m dalga + uzun periyot — kayalık ve mendirek uçlarında set dalgası seni alabilir. Islak kayaya inme.',
      'Dalga periyodu, iki dalga tepesi arasındaki süredir. Aynı boyda dalgada periyot uzadıkça kıyıya vuran güç artar.',
    ];
    return OlcumYorum(
      baslik: 'Dalga periyodu',
      deger: '${sn.toStringAsFixed(1)} sn',
      durum: tehlike
          ? 'Güçlü soluğan: kayalıklarda tehlikeli'
          : const ['Kısa: çırpıntılı, bulanık kıyı', 'Orta: köpük hattı oluşur', 'Uzun: soluğan, dip kazınır'][s],
      ton: tehlike ? Ton.zayif : (s == 1 ? Ton.iyi : Ton.orta),
      mesafe: const [Mesafe.yakin, Mesafe.yakinOrta, Mesafe.orta][s],
      maddeler: maddeler,
      kurallar: periyotKurallari,
      aktif: s,
      not: 'Deniz modeli tahminidir. Boğaz ve körfez içlerinde dalga modeli güvenilir değildir, bu yüzden orada gösterilmez.',
    );
  }

  // ---------------------------------------------------------------- Bulut
  static const bulutKurallari = <(String, String)>[
    ('%0–30 (açık)', 'Güçlü ışık: balık gün içinde derine ve gölgeye çekilir. Şafak, akşam ve gece öne çıkar.'),
    ('%30–75 (parçalı)', 'Olağan. Bulut gölgesi geçerken atak artar.'),
    ('%75–100 (kapalı)', 'Az ışık: balık gün içinde de sığa ve yüzeye yaklaşır. Levrek ve lüfer için iyi.'),
  ];

  static OlcumYorum bulut(int yuzde) {
    final s = yuzde < 30 ? 0 : (yuzde < 75 ? 1 : 2);
    return OlcumYorum(
      baslik: 'Bulut',
      deger: '%$yuzde',
      durum: const ['Açık hava: gündüz balık derinde', 'Parçalı: olağan', 'Kapalı: balık sığa yaklaşır'][s],
      ton: const [Ton.orta, Ton.orta, Ton.iyi][s],
      mesafe: const [Mesafe.orta, Mesafe.yakinOrta, Mesafe.yakin][s],
      maddeler: [
        bulutKurallari[s].$2,
        if (s == 0) 'Renk: doğal ve şeffaf tonlar (gümüş, sardalya, şeffaf silikon), ince floro lider.',
        if (s == 2) 'Renk: belirgin silüet veren koyu (siyah, mor sırt) ya da parlak (chartreuse, pembe) yemler.',
        if (s == 1) 'Renk: doğal tonlar; güneş çıktıkça bir ton açığa, kapandıkça koyuya geç.',
        'Gece avında açık gökyüzü + dolunay suyu aydınlatır; kapalı gecede fosforlu ve ses çıkaran yemler daha etkilidir.',
      ],
      kurallar: bulutKurallari,
      aktif: s,
      not: 'Bulutluluk tüm gökyüzünün kapalı olan yüzdesidir.',
    );
  }

  // ---------------------------------------------------------------- Uydu su sıcaklığı
  /// Kıyı balıklarının yaklaşık rahat ettiği su sıcaklıkları (°C)
  static const turAraliklari = <(String, double, double)>[
    ('Mezgit', 6, 14),
    ('Levrek', 10, 24),
    ('İstavrit', 10, 22),
    ('İskorpit', 10, 22),
    ('Lüfer', 13, 22),
    ('Palamut', 14, 22),
    ('Karagöz', 13, 25),
    ('Çipura', 14, 26),
    ('Mırmır', 17, 27),
    ('Kefal', 8, 28),
  ];

  static List<String> uygunTurler(double sst) =>
      [for (final t in turAraliklari) if (sst >= t.$2 && sst <= t.$3) t.$1];

  static const sstKurallari = <(String, String)>[
    ('5 günde 0,8°C ve fazla soğuma', 'Sonbaharda göçü tetikler (palamut, lüfer, istavrit kıyıya iner). Kışın ani soğuma balığı yavaşlatır.'),
    ('±0,8°C içinde', 'Sabit su: balık düzenini korur.'),
    ('5 günde 0,8°C ve fazla ısınma', 'İlkbaharda balık sığa çıkar. Yazın su 25°C üstündeyse balık gündüz derine iner, gece kıyıya gelir.'),
  ];

  static OlcumYorum uyduSst(double sst, double? degisim5, int ay) {
    final c = degisim5 ?? 0;
    final s = c <= -0.8 ? 0 : (c >= 0.8 ? 2 : 1);
    final turler = uygunTurler(sst);
    final sonbahar = ay >= 9 && ay <= 12;
    final ilkbahar = ay >= 3 && ay <= 6;
    String durum;
    Ton ton;
    String mesafe;
    if (sst >= 25) {
      durum = 'Su çok ılık: gündüz derin, gece kıyı';
      ton = Ton.orta;
      mesafe = Mesafe.uzak;
    } else if (sst < 10) {
      durum = 'Su soğuk: balık yavaş ve derinde';
      ton = Ton.zayif;
      mesafe = Mesafe.uzak;
    } else if (s == 0 && sonbahar) {
      durum = 'Su soğuyor: göç başlıyor, kıyıya iner';
      ton = Ton.iyi;
      mesafe = Mesafe.yakinOrta;
    } else if (s == 2 && ilkbahar) {
      durum = 'Su ısınıyor: balık sığa çıkıyor';
      ton = Ton.iyi;
      mesafe = Mesafe.yakinOrta;
    } else if (s == 1) {
      durum = 'Sabit su sıcaklığı';
      ton = Ton.orta;
      mesafe = Mesafe.orta;
    } else {
      durum = s == 0 ? 'Su soğuyor' : 'Su ısınıyor';
      ton = Ton.orta;
      mesafe = Mesafe.orta;
    }
    return OlcumYorum(
      baslik: 'Uydu su sıcaklığı',
      deger: '${sst.toStringAsFixed(1)}°${degisim5 == null ? '' : ' (${degisim5 > 0 ? '+' : ''}${degisim5.toStringAsFixed(1)}°)'}',
      durum: durum,
      ton: ton,
      mesafe: mesafe,
      maddeler: [
        'Uydunun son günlerde ölçtüğü deniz yüzeyi sıcaklığı ${sst.toStringAsFixed(1)}°C. Parantezdeki değer son 5 gündeki değişimdir.',
        sstKurallari[s].$2,
        if (turler.isNotEmpty) 'Bu sıcaklıkta rahat eden türler: ${turler.join(', ')}.',
      ],
      kurallar: sstKurallari,
      aktif: s,
      not: 'Uydu ölçümü (1 km). Tür aralıkları yaklaşıktır. Uydu yüzeyi ölçer; 10 m altındaki su daha serin olabilir.',
    );
  }

  // ---------------------------------------------------------------- Klorofil
  static const klorofilKurallari = <(String, String)>[
    ('0,5 mg/m³ altı', 'Berrak, besin az. Yem balığı dağınık; balık derinde. Uzun atış, doğal renk.'),
    ('0,5–3 mg/m³', 'Verimli su. Plankton → hamsi, istavrit, gümüş → avcı balık zinciri canlı.'),
    ('3–10 mg/m³', 'Çok verimli, yeşilimsi su. Yem balığı bol; görüş kısa — parlak, titreşimli ve kokulu yemler.'),
    ('10 mg/m³ üstü', 'Aşırı (alg patlaması). Marmara\'da müsilaj riski; oksijen düşebilir, balık bölgeden uzaklaşabilir.'),
  ];

  static OlcumYorum klorofil(double mg, int? degisimYuzde) {
    final s = mg < 0.5 ? 0 : (mg < 3 ? 1 : (mg <= 10 ? 2 : 3));
    final p = degisimYuzde;
    final artis = p != null && p >= 15;
    final azalis = p != null && p <= -20;
    return OlcumYorum(
      baslik: 'Klorofil (yem balığı)',
      deger: '${mg.toStringAsFixed(1)} mg/m³${p == null ? '' : ' (${p > 0 ? '+' : ''}%$p)'}',
      durum: artis
          ? 'Artıyor: yem balığı toplanabilir'
          : (azalis ? 'Azalıyor: yem balığı dağılıyor' : const ['Düşük: berrak, fakir su', 'Verimli su', 'Çok verimli su', 'Aşırı: alg/müsilaj riski'][s]),
      ton: s == 3 ? Ton.zayif : (artis || s == 1 || s == 2 ? Ton.iyi : Ton.orta),
      mesafe: s == 0 ? Mesafe.uzak : (s == 3 ? Mesafe.orta : Mesafe.yakinOrta),
      maddeler: [
        'Klorofil, sudaki bitkisel planktonun ölçüsüdür. Plankton çoğaldığı yerde hamsi, istavrit, gümüş ve sardalya toplanır; levrek, lüfer, palamut da onların peşinden gelir.',
        klorofilKurallari[s].$2,
        if (artis) 'Son günlerde %$p artış var: yem balığı genelde 3–5 gün içinde bölgeye yığılır. Çapari ve LRF ile yem balığını, maket ve jig ile avcıyı ara.',
        if (azalis) 'Son günlerde %${-(p ?? 0)} azalma var: yem balığı başka yere kayıyor olabilir; komşu meralara da bak.',
      ],
      kurallar: klorofilKurallari,
      aktif: s,
      not: 'Uydu ölçümü (9 km çözünürlük). Kıyı şeridinin değil, merayı çevreleyen açık suyun ortalamasıdır.',
    );
  }

  // ---------------------------------------------------------------- Model uyumu
  static OlcumYorum modelUyumu(String seviye, double ortalama, int modelSayisi) {
    final s = seviye == 'Yüksek' ? 0 : (seviye == 'Orta' ? 1 : 2);
    return OlcumYorum(
      baslik: 'Model uyumu',
      deger: '$seviye · ort. ${ortalama.round()} km/s',
      durum: const ['Tahmin güvenilir', 'Tahmin kısmen güvenilir', 'Hava değişken: tahmine güvenme'][s],
      ton: const [Ton.iyi, Ton.orta, Ton.zayif][s],
      maddeler: [
        '$modelSayisi ayrı hava modelinin önümüzdeki 6 saatlik rüzgâr tahmini karşılaştırılır. Ortalama ${ortalama.round()} km/s.',
        const [
          'Modeller aynı şeyi söylüyor: planını rahatça yapabilirsin.',
          'Modeller arasında fark var: yola çıkmadan önce raporu bir kez daha kontrol et.',
          'Modeller çok farklı: rüzgâr beklenenden sert gelebilir. Korunaklı yedek mera ve bir üst gramaj takım al.',
        ][s],
      ],
      kurallar: const [
        ('Yüksek', 'Modeller arası fark 6 km/s içinde.'),
        ('Orta', 'Fark 6–12 km/s.'),
        ('Düşük', 'Fark 12 km/s üstünde.'),
      ],
      aktif: s,
    );
  }

  // ---------------------------------------------------------------- Diğer ölçümler
  static OlcumYorum akinti(double kmh) {
    final s = kmh < 0.5 ? 0 : (kmh < 2 ? 1 : (kmh < 3 ? 2 : 3));
    return OlcumYorum(
      baslik: 'Akıntı',
      deger: '${kmh.toStringAsFixed(1)} km/s',
      durum: const ['Durgun su', 'İdeal akıntı: yem taşınıyor', 'Güçlü akıntı', 'Sert akıntı: takım sürüklenir'][s],
      ton: const [Ton.orta, Ton.iyi, Ton.orta, Ton.zayif][s],
      mesafe: const [Mesafe.orta, Mesafe.yakinOrta, Mesafe.yakin, Mesafe.yakin][s],
      maddeler: [
        const [
          'Su durgun: balık beslenmek için dolaşır, dağınıktır. Yemi hareketli tut, sık yer değiştir.',
          'Hafif akan su yemi taşır, balığı akıntıya karşı dizer. Yemi akıntının yukarısına atıp doğal sürüklenmesini sağla.',
          'Akıntı güçlü: balık akıntının kırıldığı yerlerde (burun arkası, mendirek dibi, anafor) bekler.',
          'Sert akıntıda takım tutmaz: ağır kurşun/jig kullan ya da akıntının kırıldığı koylara geç (Boğaz\'da orkoz ve anafor cepleri).',
        ][s],
      ],
      kurallar: const [
        ('0,5 km/s altı', 'Durgun'),
        ('0,5–2 km/s', 'İdeal'),
        ('2–3 km/s', 'Güçlü'),
        ('3 km/s üstü', 'Sert'),
      ],
      aktif: s,
      not: 'Deniz modeli tahmini (yüzey akıntısı).',
    );
  }

  static OlcumYorum dalga(double? m, bool korunakli) {
    if (korunakli || m == null) {
      return const OlcumYorum(
        baslik: 'Dalga',
        deger: 'Korunaklı su',
        durum: 'Boğaz/körfez içi: dalga yerine rüzgâr ve akıntıya bak',
        maddeler: ['Dalga modelleri dar suları çözümleyemez. Bu merada av koşulunu rüzgâr, hamle ve akıntı belirler.'],
      );
    }
    final s = m < 0.3 ? 0 : (m < 0.8 ? 1 : (m < 1.2 ? 2 : 3));
    return OlcumYorum(
      baslik: 'Dalga',
      deger: '${m.toStringAsFixed(1)} m',
      durum: const ['Çarşaf deniz: berrak su', 'İdeal dalga', 'Sert dalga: ağır takım', 'Tehlikeli dalga'][s],
      ton: const [Ton.orta, Ton.iyi, Ton.orta, Ton.zayif][s],
      mesafe: const [Mesafe.orta, Mesafe.yakin, Mesafe.yakinOrta, ''][s],
      maddeler: [
        const [
          'Sakin ve berrak suda balık temkinlidir: uzun atış, ince lider, doğal renk. Şafak ve akşam daha verimli.',
          'Hafif dalga suyu karıştırır, yem açığa çıkar, köpük hattı oluşur — levrek için en iyi koşul.',
          'Dalga sert: bir üst gramaj jig/kurşun kullan, köpük hattını yakından tara.',
          'Dalga tehlikeli: kayalık ve mendirek uçlarına çıkma. Korunaklı koy ya da liman içi seç.',
        ][s],
      ],
      kurallar: const [
        ('0,3 m altı', 'Çarşaf'),
        ('0,3–0,8 m', 'İdeal'),
        ('0,8–1,2 m', 'Sert'),
        ('1,2 m üstü', 'Tehlikeli'),
      ],
      aktif: s,
    );
  }

  static OlcumYorum ruzgar(double? kmh, String yon) {
    final w = kmh ?? 0;
    final s = w < 10 ? 0 : (w < 20 ? 1 : (w < 30 ? 2 : 3));
    return OlcumYorum(
      baslik: 'Rüzgâr',
      deger: '${w.round()} km/s $yon'.trim(),
      durum: const ['Hafif: her disipline uygun', 'Orta: atışa uygun', 'Sert: ağır takım', 'Çok sert: korunaklı kıyı'][s],
      ton: const [Ton.iyi, Ton.iyi, Ton.orta, Ton.zayif][s],
      maddeler: [
        const [
          'Hafif rüzgârda LRF ve hafif spin rahat yapılır.',
          'Kıyıya doğru esen rüzgâr yem balığını ve köpüğü kıyıya iter; avcı balık da peşinden gelir. Rüzgârın vurduğu kıyıyı dene.',
          'Rüzgâr atışı zorlaştırır: bir üst gramaj, rüzgârı arkana alabileceğin kıyı seç.',
          'Rüzgâr çok sert: güvenlik için korunaklı koy, liman ya da körfez içine geç.',
        ][s],
        if (yon.isNotEmpty) 'Yön: $yon. Rüzgâr kıyıdan açığa doğru esiyorsa yüzey suyu açılır, balık derine iner; kıyıya doğru esiyorsa yem kıyıya yığılır.',
      ],
    );
  }

  static OlcumYorum hamle(double kmh) {
    final s = kmh < 30 ? 0 : (kmh < 45 ? 1 : 2);
    return OlcumYorum(
      baslik: 'Hamle',
      deger: '${kmh.round()} km/s',
      durum: const ['Hamleler zararsız', 'Sert hamle: atış ve kontrol zor', 'Tehlikeli hamle'][s],
      ton: const [Ton.iyi, Ton.orta, Ton.zayif][s],
      maddeler: const [
        'Hamle, rüzgârın kısa süreli en yüksek hızıdır. Kıyıda atışı asıl hamleler zorlar.',
        '45 km/s üstü hamlede kayalık, mendirek ve iskele uçlarında durma.',
      ],
    );
  }

  static OlcumYorum yagis(double mm) {
    final s = mm < 1 ? 0 : (mm < 8 ? 1 : (mm < 20 ? 2 : 3));
    return OlcumYorum(
      baslik: 'Yağış (gün)',
      deger: '${mm.toStringAsFixed(mm < 10 ? 1 : 0)} mm',
      durum: const ['Kuru', 'Hafif yağış: sorun değil', 'Yağışlı: dere ağızları bulanık', 'Sağanak: tatlı su girişi'][s],
      ton: const [Ton.orta, Ton.iyi, Ton.orta, Ton.zayif][s],
      mesafe: const ['', Mesafe.yakinOrta, Mesafe.yakin, Mesafe.uzak][s],
      maddeler: const [
        'Hafif yağmur yüzeyi kırar, ışığı azaltır; balık daha cesur olur.',
        'Yağış sonrası dere ve kanal ağızlarına gelen bulanık su yem taşır: levrek ve kefal ağız çevresinde beslenir.',
        'Çok yağışta kıyıya tatlı su ve çamur girer, tuzluluk düşer; balık açığa ve temiz suya çekilir.',
      ],
    );
  }

  static OlcumYorum suHava(double? su, double? hava) {
    final fark = (su != null && hava != null) ? hava - su : null;
    return OlcumYorum(
      baslik: 'Su / Hava',
      deger: '${su?.round() ?? '-'}° / ${hava?.round() ?? '-'}°',
      durum: su == null ? 'Su sıcaklığı yok' : (Yorum.uygunTurler(su).isEmpty ? 'Su sıcaklığı kıyı türleri için sınırda' : 'Uygun türler: ${Yorum.uygunTurler(su).take(4).join(', ')}'),
      maddeler: [
        'Su sıcaklığı deniz modelinden, hava sıcaklığı 2 m yükseklikten.',
        if (fark != null && fark <= -6) 'Hava sudan çok soğuk: sığ su gece soğur; balık öğleye doğru ısınan sığ kıyıya gelir.',
        if (fark != null && fark >= 6) 'Hava sudan çok sıcak: yüzey ısınır; balık gündüz derinde, akşam ve gece kıyıda.',
        'Daha doğru değer için "Uydu su sıcaklığı" kutusuna dokun.',
      ],
    );
  }

  static OlcumYorum uyeAvi(int adet, String sonBalik) => OlcumYorum(
        baslik: 'Son 48 saat üye avı',
        deger: '$adet bildirim · $sonBalik',
        durum: adet >= 3 ? 'Mera aktif: balık geçiyor' : 'Merada av var',
        ton: Ton.iyi,
        maddeler: const [
          'Bu meradan son 48 saatte gelen, yönetici onaylı üye av bildirimleri.',
          'Aynı balık genelde aynı saatlerde ve aynı yemle tekrar gelir: bildirimlerdeki saat ve yeme bak.',
        ],
      );
}
