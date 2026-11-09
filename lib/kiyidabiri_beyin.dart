import 'dart:math' as math;

import 'balik_rehberi.dart';
import 'config.dart';
import 'freshwater.dart';
import 'mera.dart';
import 'mera_oner.dart';
import 'models.dart';
import 'sea.dart';
import 'solunar.dart';

/// 1.14.0 — Kıyıdabiri'nin "beyni": yalnızca uygulamanın kendi verisinden (meralar, deniz/hava tahmini,
/// kıyı kesiti, bölge balıkları, tatlı su veri seti, topluluk meraları, mağaza araması) yanıt üretir.
/// Uydurma yanıt vermez: veri yetmezse müşteri temsilcisine (WhatsApp) yönlendirmeyi önerir.
/// Ağ ve veri erişimi [KbVeri] üzerinden yapılır (testte sahte veriyle çalışır).

/// Türkçe karakterleri sadeleştirip küçültür ("Rumelifeneri'nde" → "rumelifenerinde")
String kbNorm(String s) {
  const tr = {'ı': 'i', 'İ': 'i', 'I': 'i', 'ğ': 'g', 'Ğ': 'g', 'ü': 'u', 'Ü': 'u', 'ş': 's', 'Ş': 's', 'ö': 'o', 'Ö': 'o',
    'ç': 'c', 'Ç': 'c', 'â': 'a', 'î': 'i', 'û': 'u'};
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(tr[c] ?? c.toLowerCase());
  }
  return b.toString().replaceAll(RegExp(r"['’`]"), '').replaceAll(RegExp(r"[^a-z0-9 ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

enum KbAdim { mera, stil, kampanya, serbest, temsilci, tekneSor, tekneKisi, tekneAd, tekneTel }

enum KbEylem { whatsapp, haritadanSec, meraBilgisiAc, meraOner, toplulukMeralari, dugumler, bildirimIzni, urunAra, blogAc, urunAc }

/// Sohbet balonunda gösterilecek çizim
enum KbGorsel { mantarliTakim }

/// kiyidanav.com blog yazısı (RSS)
class KbBlogYazi {
  final String baslik, ozet, link;
  const KbBlogYazi(this.baslik, this.ozet, this.link);
}

class KbSecenek {
  final String etiket;
  /// Kullanıcının yazmış gibi gönderilecek metin (yoksa etiket)
  final String? gonder;
  final KbEylem? eylem;
  const KbSecenek(this.etiket, {this.gonder, this.eylem});
}

class KbYanit {
  final String metin;
  final List<KbSecenek> secenekler;
  final String niyet;
  /// Yanıtın ilgili olduğu mera (sohbet kaydı ve "Mera bilgisini aç" için)
  final Spot? spot;
  /// Kampanya hatırlatıcısı kurulacak ürün/kategori
  final String? kampanya;
  final KbGorsel? gorsel;
  /// Kullanıcının yazdığı metin sohbet kaydına yazılmasın (telefon numarası adımı)
  final bool girdiGizli;
  /// Tekne avı talebi tamamlandı (sunucuya gönderildi)
  final Map<String, String>? tekneTalebi;
  const KbYanit(this.metin,
      {this.secenekler = const [],
      this.niyet = '',
      this.spot,
      this.kampanya,
      this.gorsel,
      this.girdiGizli = false,
      this.tekneTalebi});
}

/// Avlanma stilleri ve koşul tercihleri (deniz)
class KbStil {
  final String ad;
  final List<String> anahtar;
  final double ruzgarMax; // km/s (etkin rüzgâr)
  final double dalgaMin, dalgaMax; // m
  final bool bogazIyi; // Boğaz/körfez içi akıntılı sular uygun mu
  final bool bogazOlmaz; // açık kıyı şart mı (surf)
  final List<String> turler; // baliklar anahtarları
  final String ipucu;
  const KbStil(this.ad, this.anahtar,
      {required this.ruzgarMax,
      required this.dalgaMin,
      required this.dalgaMax,
      this.bogazIyi = false,
      this.bogazOlmaz = false,
      this.turler = const [],
      this.ipucu = ''});

  /// 0–1: bugünkü koşulların bu stile uygunluğu
  double uygunluk(SeaReport r) {
    var u = 1.0;
    final w = r.effectiveWind;
    if (w > ruzgarMax) u -= math.min(0.7, (w - ruzgarMax) / 25);
    if (r.strait) {
      if (bogazOlmaz) u -= 0.6;
      if (bogazIyi) u += 0.1;
    } else {
      final d = r.effectiveWave;
      if (d < dalgaMin) u -= math.min(0.4, (dalgaMin - d) * 0.8);
      if (d > dalgaMax) u -= math.min(0.8, (d - dalgaMax) * 0.9);
    }
    return u.clamp(0.05, 1.1);
  }
}

const kbStiller = <KbStil>[
  KbStil('LRF', ['lrf', 'light rock', 'hafif'],
      ruzgarMax: 18, dalgaMin: 0, dalgaMax: 0.5, bogazIyi: true,
      turler: ['istavrit', 'sargoz', 'karagoz', 'isparoz', 'eskina', 'lidaki'],
      ipucu: '1–7 g jig head + 1.5–2 inç silikon; ışıklı iskele ve kaya dipleri, akşam karanlığı.'),
  KbStil('Spin', ['spin', 'rapala', 'kasik', 'sahte'],
      ruzgarMax: 28, dalgaMin: 0.3, dalgaMax: 1.1, bogazIyi: true,
      turler: ['levrek', 'lufer', 'palamut', 'cinekop'],
      ipucu: 'Hafif dalgada köpük hattına 10–30 g sahte; şafak ve gün batımı en verimli.'),
  KbStil('Surf', ['surf', 'surfcasting', 'atma'],
      ruzgarMax: 30, dalgaMin: 0.4, dalgaMax: 1.4, bogazOlmaz: true,
      turler: ['mirmir', 'cupra', 'levrek', 'minekop', 'kalkan'],
      ipucu: 'Kum zeminde boru kurdu / mamun; dalga kırılma hattının arkasına at, gece verimli.'),
  KbStil('Çapari', ['capari', 'zoka'],
      ruzgarMax: 25, dalgaMin: 0, dalgaMax: 0.8, bogazIyi: true,
      turler: ['istavrit', 'kolyoz', 'uskumru'],
      ipucu: 'Sürü geldiğinde 8–10 iğneli çapari, 30–60 g kurşun; sabah erken.'),
  KbStil('Kurşun arkası', ['kursun arkasi', 'kursun'],
      ruzgarMax: 25, dalgaMin: 0, dalgaMax: 0.9, bogazIyi: true,
      turler: ['lufer', 'zargana', 'cinekop', 'mezgit'],
      ipucu: 'Akıntılı burunlarda 1–2 m köstek, kurşun 40–80 g; lüfer için çelik tel.'),
  KbStil('Şamandıra', ['samandira', 'mantar', 'yuzer'],
      ruzgarMax: 20, dalgaMin: 0, dalgaMax: 0.5,
      turler: ['kefal', 'karagoz', 'zargana', 'mirmir'],
      ipucu: 'Sakin, korunaklı kıyı; hamur / karides, ince misina.'),
  KbStil('Shore jigging', ['jig', 'jigging', 'shore jig'],
      ruzgarMax: 26, dalgaMin: 0, dalgaMax: 1.0, bogazIyi: true,
      turler: ['palamut', 'lufer', 'akya'],
      ipucu: '20–60 g metal jig; kıyıya yakın derinleşen burunlar.'),
];

KbStil? kbStilBul(String metin) {
  final n = kbNorm(metin);
  for (final s in kbStiller) {
    for (final a in s.anahtar) {
      if (RegExp('(^| )$a( |\$)').hasMatch(n) || n.contains(a)) return s;
    }
  }
  return null;
}

/// Eşleşen mera: deniz merası (hazır, nokta, topluluk) ya da göl/baraj
class KbMera {
  final String ad;
  final Spot? spot;
  final FwPlace? gol;
  final MeraOnerisi? oneri;
  const KbMera(this.ad, {this.spot, this.gol, this.oneri});
}

/// Veri erişimi (uygulamada gerçek servisler, testte sahte)
abstract class KbVeri {
  Spot get secili;
  bool get uye;
  /// Seçilebilir deniz meraları (üye değilse yalnız İstanbul yakaları) + nokta meralar
  List<Spot> denizMeralari();
  List<MeraOnerisi> topluluk();
  Future<FwData?> tatliSu();
  Future<SpotForecast> hafta(Spot s);
  Future<List<SpotForecast>> simdi(List<Spot> l);
  Future<MeraInfo?> kesit(Spot s);
  Future<List<ProductCard>> urunAra(String q);
  /// kiyidanav.com/blog yazıları (RSS)
  Future<List<KbBlogYazi>> blog();
  /// Tekne avı talebini sunucuya gönderir (ad, telefon, kişi sayısı)
  Future<bool> tekneTalep(Map<String, String> talep);
  /// kiyidanav.com'da şu an indirimde olan ürünler (vitrinden; en yüksek indirim başta)
  Future<List<ProductCard>> indirimliler();
  /// Panelden gönderilen güncel kampanya duyuruları (başlıklar)
  Future<List<String>> kampanyaDuyurulari();
  /// 1.16.0: listede olmayan yer adını haritada bulur (kıyıya yakınsa en yakın meranın bilgileriyle nokta)
  Future<Spot?> yerBul(String ad);
}

/// Stile göre ekipman bilgisi ve mağazada aranacak kelimeler
class KbEkipman {
  final String kamis, makine, misina, yem, aksesuar;
  final List<String> ara;
  const KbEkipman({required this.kamis, required this.makine, required this.misina, required this.yem, this.aksesuar = '',
      required this.ara});
}

const kbEkipmanlar = <String, KbEkipman>{
  'LRF': KbEkipman(
      kamis: '1,80–2,30 m, 0,5–8 g atma ağırlığı, hassas (solid) uçlu LRF kamışı',
      makine: '1000–2000 boy, hafif ve ince fren ayarlı',
      misina: 'PE 0,3–0,6 ip misina + 0,14–0,18 mm florokarbon lider',
      yem: '1–5 g jig head + 1,5–2,5 inç silikon, mini rapala ve kaşık',
      aksesuar: 'jig head kutusu, kafa lambası',
      ara: ['lrf kamış', 'lrf makine', 'jig head']),
  'Spin': KbEkipman(
      kamis: '2,70–3,00 m, 10–40 g spin kamışı',
      makine: '3000–4000 boy, su sıçramasına dayanıklı',
      misina: 'PE 0,8–1,2 ip misina + 0,28–0,35 mm florokarbon lider (lüferde çelik tel)',
      yem: '9–14 cm rapala (minnow), 20–30 g kaşık, silikon shad',
      aksesuar: 'sahte kutusu, karabina–fırdöndü',
      ara: ['spin kamış', 'olta makinesi', 'rapala']),
  'Surf': KbEkipman(
      kamis: '4,20–4,50 m, 100–250 g surf kamışı',
      makine: '6000–8000 boy, uzun makaralı surf makinesi',
      misina: '0,30–0,35 mm misina + 0,50–0,60 mm şok lider',
      yem: '100–150 g piramit kurşun; boru kurdu, mamun, karides',
      aksesuar: 'tripod, uç ışığı / zil',
      ara: ['surf kamış', 'surf makine', 'surf kurşun']),
  'Çapari': KbEkipman(
      kamis: '3,00–4,20 m, 50–150 g kamış',
      makine: '4000–5000 boy',
      misina: '0,30–0,35 mm misina',
      yem: 'hazır çapari (6–10 iğne), 40–80 g kurşun',
      ara: ['çapari', 'olta kamışı']),
  'Kurşun arkası': KbEkipman(
      kamis: '2,40–3,00 m, 30–80 g kamış (teknede kısa tekne kamışı)',
      makine: '3000–4000 boy',
      misina: '0,30 mm misina, 1–2 m 0,28–0,30 mm florokarbon köstek (lüfere çelik tel)',
      yem: '40–100 g kurşun, fileto hamsi / istavrit',
      aksesuar: 'fırdöndü, boncuk',
      ara: ['kurşun', 'florokarbon', 'fırdöndü']),
  'Şamandıra': KbEkipman(
      kamis: '3,60–4,20 m bolognese / şamandıra kamışı, 5–20 g',
      makine: '2500–3000 boy',
      misina: '0,20–0,25 mm misina',
      yem: '2–8 g şamandıra, 8–12 numara iğne; hamur, ekmek, karides',
      ara: ['şamandıra', 'olta kamışı']),
  'Shore jigging': KbEkipman(
      kamis: '2,70–3,00 m, 30–80 g jig kamışı',
      makine: '4000–5000 boy, yüksek dişli oranı',
      misina: 'PE 1,0–1,5 ip misina + 0,40–0,50 mm florokarbon lider',
      yem: '20–60 g metal jig, asist iğne',
      ara: ['metal jig', 'jig kamış', 'ip misina']),
};

/// Balık → en uygun stil (ekipman önerisi için)
const _balikStil = {
  'levrek': 'Spin', 'lufer': 'Spin', 'cinekop': 'Kurşun arkası', 'palamut': 'Spin', 'istavrit': 'Çapari', 'kolyoz': 'Çapari',
  'cupra': 'Surf', 'cipura': 'Surf', 'mirmir': 'Surf', 'minekop': 'Surf', 'kalkan': 'Surf', 'sargoz': 'LRF', 'karagoz': 'LRF',
  'isparoz': 'LRF', 'eskina': 'LRF', 'lidaki': 'LRF', 'kefal': 'Şamandıra', 'zargana': 'Şamandıra', 'akya': 'Shore jigging',
};

class KiyidabiriBeyin {
  final KbVeri veri;
  KbAdim adim = KbAdim.serbest;
  Spot? sonMera;
  KbStil? sonStil;
  final Map<String, String> _tekne = {};
  KiyidabiriBeyin(this.veri);

  static const karsilama = 'Merhaba, ben Kıyıdabiri! Mera, hava, ekipman, ürün ve kampanyalar hakkında sorunu yaz; kısa ve net yanıtlayayım.';
  static const temsilciSorusu = 'Müşteri temsilcisine bağlanmak ister misiniz?';

  List<KbSecenek> get acilisSecenekleri => [
        KbSecenek('📍 ${veri.secili.name} bugün', gonder: veri.secili.name),
        const KbSecenek('Ekipman öner', gonder: 'ekipman öner'),
        const KbSecenek('Kampanyalar', gonder: 'kampanyalar'),
        const KbSecenek('Stilime göre mera', gonder: 'hangi stil'),
        const KbSecenek('Tekne avı', gonder: 'tekne avı'),
      ];

  static const _stilSecenekleri = [
    KbSecenek('LRF'), KbSecenek('Spin'), KbSecenek('Surf'), KbSecenek('Çapari'),
    KbSecenek('Kurşun arkası'), KbSecenek('Şamandıra'), KbSecenek('Shore jigging'),
  ];
  static const _kampanyaSecenekleri = [
    KbSecenek('Olta makinesi'), KbSecenek('Olta kamışı'), KbSecenek('Suni yem'), KbSecenek('Misina'),
    KbSecenek('Kamp ürünleri'), KbSecenek('Şimdilik istemem', gonder: 'istemem'),
  ];

  // ------------------------------------------------------------------ ana giriş
  Future<KbYanit> yanitla(String girdi) async {
    final n = kbNorm(girdi);
    if (n.isEmpty) return const KbYanit('Bir şey yazmadın gibi görünüyor 🙂', niyet: 'bos');

    // Tekne avı talebi adımları
    final t = await _tekneAdimi(girdi.trim(), n);
    if (t != null) return t;

    // Temsilci sorusuna yanıt
    if (adim == KbAdim.temsilci) {
      adim = KbAdim.serbest;
      if (_evet(n)) {
        return const KbYanit('Seni WhatsApp destek hattımıza yönlendiriyorum. Mesajını oradan yazabilirsin.',
            niyet: 'temsilci_evet', secenekler: [KbSecenek('WhatsApp\'ta yaz', eylem: KbEylem.whatsapp)]);
      }
      if (_hayir(n)) return const KbYanit('Peki! Başka bir sorun olursa buradayım.', niyet: 'temsilci_hayir');
    }

    // Her adımda geçerli kısa yollar
    if (_icerir(n, ['temsilci', 'canli destek', 'insan', 'yetkili', 'musteri hizmet', 'whatsapp'])) {
      return _temsilciyeYonlendir('Seni hemen müşteri temsilcimize bağlayabilirim.', niyet: 'temsilci');
    }
    // Kampanyalar: güncel indirimler (hatırlatıcı yalnızca "haber ver" denince)
    if (adim != KbAdim.kampanya && _icerir(n, ['kampanya', 'indirim', 'firsat', 'ucuz']) && !_icerir(n, ['haber ver', 'hatirlat', 'bildir'])) {
      return kampanyaListesi();
    }
    if (_icerir(n, ['haber ver', 'hatirlat']) && adim != KbAdim.kampanya) {
      adim = KbAdim.kampanya;
      return const KbYanit('Hangi üründe kampanya istersin? Ürün ya da kategori adını yaz; indirim olunca sana bildirim gelsin.',
          niyet: 'kampanya_sor', secenekler: _kampanyaSecenekleri);
    }

    switch (adim) {
      case KbAdim.mera:
        if (_icerir(n, ['baska bir sorum', 'baska soru', 'sorum var'])) {
          adim = KbAdim.serbest;
          return const KbYanit('Tabii, sor bakalım! Meralar, hava ve deniz durumu, balık türleri, yem ve teknik, kargo… '
              'Mera bilgilerimizden yanıtlamaya çalışırım.', niyet: 'serbest_bas');
        }
        if (cinekopSorusu(n)) return cinekopYaniti();
        var m = _meraBul(n);
        // 1.16.0: listede yoksa yer adı olarak haritada ara ("diliskelesi", "dilovası")
        if (m == null && n.split(' ').length <= 4 && !n.contains('?')) {
          final yer = await veri.yerBul(n);
          if (yer != null) m = KbMera(yer.name, spot: yer);
        }
        if (m == null) {
          final y = await _serbest(n);
          if (y != null) return y;
          return KbYanit('Bu merayı tanıyamadım. Mera adını yazabilir ya da haritadan seçebilirsin. '
              'Listede yoksa "Mera öner" ile ekleyebilirsin.',
              niyet: 'mera_bulunamadi',
              secenekler: const [
                KbSecenek('Haritadan seç', eylem: KbEylem.haritadanSec),
                KbSecenek('Mera öner', eylem: KbEylem.meraOner),
                KbSecenek('Başka bir sorum var', gonder: 'başka bir sorum var'),
              ]);
        }
        final ozet = await meraOzeti(m);
        adim = KbAdim.serbest;
        return KbYanit(ozet, niyet: 'mera', spot: m.spot ?? sonMera, secenekler: [
          if (m.spot != null) const KbSecenek('Mera bilgisini aç', eylem: KbEylem.meraBilgisiAc),
          const KbSecenek('Stilime göre mera', gonder: 'hangi stil'),
          const KbSecenek('Ekipman öner', gonder: 'ekipman öner'),
        ]);
      case KbAdim.stil:
        final s = kbStilBul(n);
        if (s == null) {
          final y = await _serbest(n);
          if (y != null) return y;
          return const KbYanit('Hangi stil? LRF, spin, surf, çapari, kurşun arkası, şamandıra ya da shore jigging yazabilirsin.',
              niyet: 'stil_anlasilmadi', secenekler: _stilSecenekleri);
        }
        sonStil = s;
        final oneri = await stilOnerisi(s);
        adim = KbAdim.serbest;
        return KbYanit(oneri, niyet: 'stil_${kbNorm(s.ad).replaceAll(' ', '_')}', spot: sonMera, secenekler: [
          KbSecenek('${s.ad} ekipmanı', gonder: '${s.ad} ekipmanı'),
          const KbSecenek('Mera bilgisini aç', eylem: KbEylem.meraBilgisiAc),
        ]);
      case KbAdim.kampanya:
        adim = KbAdim.serbest;
        if (_hayir(n) || _icerir(n, ['istemem', 'gerek yok', 'atla'])) {
          return const KbYanit('Tamam! Aklına bir şey gelirse sorabilirsin; mera, hava, balık ya da ürün… 🎣', niyet: 'kampanya_yok');
        }
        return kampanyaKur(girdi.trim());
      case KbAdim.serbest:
      case KbAdim.temsilci:
      case KbAdim.tekneSor:
      case KbAdim.tekneKisi:
      case KbAdim.tekneAd:
      case KbAdim.tekneTel:
        final y = await _serbest(n);
        if (y != null) return y;
        final b = await blogdaAra(n);
        if (b != null) return b;
        return _temsilciyeYonlendir('Bu soruya mera bilgilerimden ve blogumuzdan güvenilir bir yanıt bulamadım. '
            'Sorunu not aldım, ekibimize ileteceğim.', niyet: 'bilinmiyor');
    }
  }

  // ------------------------------------------------------------------ çinekop / lüfer yemli av + tekne
  static const _tekneSecenek = [KbSecenek('Evet, tekneye çıkmak isterim', gonder: 'evet'), KbSecenek('Hayır, kıyıdan', gonder: 'hayır')];

  static bool cinekopSorusu(String n) =>
      _icerir(n, ['cinekop', 'cinakop', 'lufer', 'mantarli takim', 'yemli takim', 'sarikanat', 'kofana']);

  KbYanit cinekopYaniti() {
    adim = KbAdim.tekneSor;
    final sezon = const [9, 10, 11, 12].contains(DateTime.now().month);
    return KbYanit(
        '🎣 Yemli çinekop – lüfer avı: mantarlı takım\n'
        '• Ana beden 0,30–0,35 mm misina; ucunda kayar zeytin kurşun (akıntıya göre 30–80 g) ve boncuk.\n'
        '• Boncuğun altına fırdöndü, ondan sonra 0,28–0,30 mm (tercihen florokarbon) 80–120 cm köstek.\n'
        '• İğneden 20–30 cm yukarıda köstek üzerinde mantar (köpük yüzdürücü): yemi dipten kaldırır, akıntıda oynatır.\n'
        '• İğne: uzun gövdeli; çinekop için 1–2 numara, lüfer için 1/0–2/0. İri lüfer bekleniyorsa iğne önüne 10–15 cm çelik tel.\n'
        '• Yem: taze fileto hamsi (kılçıksız şerit, deri tarafı dışta, iğneye boydan sarılır) ya da fileto istavrit. '
        'Yem taze ve parlak olmalı; 15–20 dakikada bir yenile.\n'
        '• Zaman: gün doğumu ve gün batımı; akıntılı burunlar ve mendirek uçları.\n'
        'Aşağıdaki çizimde takımın bağlanışı var. Daha fazla tavsiye için WhatsApp hattımıza yazabilirsin.\n\n'
        '🚤 ${sezon ? 'Bu dönemde kıyılar aktifleşse bile' : 'Sezonunda'} çinekop ve lüfer tekneden çok daha verimli tutuluyor. '
        'Tekne için takım önerisi: 2,10–2,70 m 20–80 g kamış, 3000–4000 boy makine, 0,30 mm misina, 60–100 g kurşunla '
        'mantarlı takım ya da çapari üstüne yemli takım; akıntıda sürükleme (kurşun arkası) da çok iyi sonuç verir.\n\n'
        'Tekne avına çıkmak ister misiniz?',
        niyet: 'cinekop',
        gorsel: KbGorsel.mantarliTakim,
        secenekler: const [
          ..._tekneSecenek,
          KbSecenek('Mantarlı takım ürünleri', gonder: 'mantarlı takım', eylem: KbEylem.urunAra),
          KbSecenek("WhatsApp'tan tavsiye al", eylem: KbEylem.whatsapp),
        ]);
  }

  Future<KbYanit?> _tekneAdimi(String ham, String n) async {
    switch (adim) {
      case KbAdim.tekneSor:
        if (_evet(n) || _icerir(n, ['tekneye cikmak', 'tekne istiyorum'])) {
          adim = KbAdim.tekneKisi;
          _tekne.clear();
          return const KbYanit('Harika! Kaç kişisiniz?', niyet: 'tekne_kisi', secenekler: [
            KbSecenek('1'), KbSecenek('2'), KbSecenek('3'), KbSecenek('4'), KbSecenek('5+', gonder: '5 kişiden fazla'),
          ]);
        }
        if (_hayir(n) || _icerir(n, ['kiyidan'])) {
          adim = KbAdim.serbest;
          return const KbYanit('Tamam, kıyıdan rastgele! 🎣 Başka bir sorun olursa buradayım.', niyet: 'tekne_hayir');
        }
        adim = KbAdim.serbest;
        return null;
      case KbAdim.tekneKisi:
        final sayi = RegExp(r'\d+').firstMatch(n)?.group(0);
        if (sayi == null) {
          return const KbYanit('Kaç kişi olacağınızı rakamla yazar mısın? (ör. 2)', niyet: 'tekne_kisi');
        }
        _tekne['kisi'] = n.contains('fazla') ? '$sayi+' : sayi;
        adim = KbAdim.tekneAd;
        return const KbYanit('Adınız ve soyadınız?', niyet: 'tekne_ad');
      case KbAdim.tekneAd:
        if (ham.trim().split(RegExp(r'\s+')).length < 2 || ham.length > 60) {
          return const KbYanit('Ad ve soyadını birlikte yazar mısın? (ör. Ali Yılmaz)', niyet: 'tekne_ad');
        }
        _tekne['ad'] = ham.trim();
        adim = KbAdim.tekneTel;
        return const KbYanit('Telefon numaranız? (ör. 05xx xxx xx xx)\n'
            'Numaran yalnızca tekne avı için sana dönüş yapmak amacıyla kullanılır.', niyet: 'tekne_tel');
      case KbAdim.tekneTel:
        final tel = ham.replaceAll(RegExp(r'[^0-9]'), '');
        if (!RegExp(r'^(90)?0?5\d{9}$').hasMatch(tel)) {
          return const KbYanit('Telefon numarası geçerli görünmüyor. 05 ile başlayan 11 haneli numaranı yazar mısın?',
              niyet: 'tekne_tel', girdiGizli: true);
        }
        _tekne['telefon'] = '0${tel.substring(tel.length - 10)}';
        _tekne['mera'] = (sonMera ?? veri.secili).name;
        adim = KbAdim.serbest;
        final talep = Map<String, String>.from(_tekne);
        var ok = false;
        try {
          ok = await veri.tekneTalep(talep);
        } catch (_) {}
        if (!ok) {
          return const KbYanit("Talebini şu an gönderemedim (bağlantı sorunu). WhatsApp'tan yazarsan ekibimiz hemen yardımcı olur.",
              niyet: 'tekne_hata', girdiGizli: true, secenekler: [KbSecenek("WhatsApp'ta yaz", eylem: KbEylem.whatsapp)]);
        }
        return KbYanit('Teşekkürler ${talep['ad']!.split(' ').first}! ${talep['kisi']} kişilik tekne avı talebini aldık; '
            'ekibimiz en kısa sürede ${talep['telefon']} numarasından sana dönüş yapacak. 🚤',
            niyet: 'tekne_talep', girdiGizli: true, tekneTalebi: talep);
      default:
        return null;
    }
  }

  // ------------------------------------------------------------------ ekipman ve ürünler
  static bool ekipmanSorusu(String n) => _icerir(n, [
        'ekipman', 'takim', 'kamis', 'makine', 'makina', 'misina', 'sahte', 'rapala', 'silikon', 'jig', 'kasik', 'igne',
        'kursun', 'olta seti', 'ne almaliyim', 'ne alayim', 'firdondu', 'lider', 'florokarbon', 'zoka',
        // 1.16.0: "hangi olta ile daha güzel av olur" gibi sorular ürün araması değil, ekipman önerisi
        'hangi olta', 'olta ile', 'hangi yem', 'ne ile avlan', 'neyle avlan', 'hangi teknik', 'nasil avlan'
      ]) && !_icerir(n, ['siparis', 'kargo', 'iade', 'mantarli takim']);

  /// "19.00'dan sonra", "akşam", "gece" gibi zaman ifadeleri
  static bool aksamSorusu(String n) =>
      _icerir(n, ['aksam', 'gece', 'karanlik', 'gun batimi', 'gunbatimi']) || RegExp(r'\b(1[7-9]|2[0-3])([.:]\d\d)?\b').hasMatch(n);

  KbStil? _stilAdi(String ad) => kbStiller.where((x) => x.ad == ad).firstOrNull;

  /// Stil ya da balığa göre ekipman önerisi + kiyidanav.com'daki uygun ürünler
  Future<KbYanit> ekipmanYaniti(String n) async {
    var stil = kbStilBul(n);
    if (stil == null) {
      for (final e in _balikStil.entries) {
        if (n.contains(e.key)) {
          stil = _stilAdi(e.value);
          break;
        }
      }
    }
    stil ??= sonStil;
    if (stil == null) {
      return const KbYanit('Hangi stil ya da balık için ekipman arıyorsun?', niyet: 'ekipman_sor', secenekler: [
        KbSecenek('LRF', gonder: 'LRF ekipmanı'), KbSecenek('Spin', gonder: 'Spin ekipmanı'), KbSecenek('Surf', gonder: 'Surf ekipmanı'),
        KbSecenek('Çapari', gonder: 'Çapari ekipmanı'), KbSecenek('Levrek', gonder: 'levrek ekipmanı'),
        KbSecenek('Çinekop', gonder: 'çinekop ekipmanı'), KbSecenek('Şamandıra', gonder: 'Şamandıra ekipmanı'),
      ]);
    }
    sonStil = stil;
    final e = kbEkipmanlar[stil.ad]!;
    // Kullanıcı belirli bir parça sorduysa mağazada önce onu ara
    final parca = _icerir(n, ['makine', 'makina'])
        ? '${stil.ad} makine'
        : _icerir(n, ['kamis'])
            ? '${stil.ad} kamış'
            : _icerir(n, ['misina', 'ip misina', 'lider', 'florokarbon'])
                ? (_icerir(n, ['ip']) ? 'ip misina' : 'misina')
                : _icerir(n, ['sahte', 'rapala', 'silikon', 'kasik', 'jig'])
                    ? e.ara.last
                    : null;
    final b = StringBuffer('🎣 ${stil.ad} için ekipman\n'
        '• Kamış: ${e.kamis}\n• Makine: ${e.makine}\n• Misina: ${e.misina}\n• Yem / sahte: ${e.yem}'
        '${e.aksesuar.isNotEmpty ? '\n• Yardımcılar: ${e.aksesuar}' : ''}');
    if (aksamSorusu(n)) {
      b.write('\n\n🌙 Akşam ve gece: gün batımından sonra büyük balık kıyıya yaklaşır; ilk 10–30 metreyi ve ışıklı iskele, '
          'kaya diplerini tara. Toplamayı yavaşlat, fosforlu ya da UV silikon dene; kafa lambasını suya tutma. '
          '${sonMera != null ? '${sonMera!.name} için saatlik rüzgâr ve dalgayı Mera Bilgisi\'nde görebilirsin.' : ''}');
    }
    final urunler = await _urunBul([if (parca != null) parca, ...e.ara.take(2)]);
    if (urunler.isNotEmpty) {
      b.write('\n\nkiyidanav.com\'da uygun ürünler:');
      for (final u in urunler) {
        b.write('\n• ${u.name}: ${_fiyat(u)}');
      }
    }
    return KbYanit(b.toString(), niyet: 'ekipman_${kbNorm(stil.ad).replaceAll(' ', '_')}', secenekler: [
      for (final u in urunler) KbSecenek('🛒 ${_kisa(u.name)}', gonder: '${u.id}', eylem: KbEylem.urunAc),
      KbSecenek('Mağazada ara', gonder: e.ara.first, eylem: KbEylem.urunAra),
      const KbSecenek('Kampanyalar', gonder: 'kampanyalar'),
    ]);
  }

  /// En fazla 3 ürün: önce indirimdekiler
  Future<List<ProductCard>> _urunBul(List<String> sorgular) async {
    final hepsi = <int, ProductCard>{};
    for (final q in sorgular.toSet()) {
      try {
        for (final u in await veri.urunAra(q)) {
          if (u.inStock) hepsi.putIfAbsent(u.id, () => u);
        }
      } catch (_) {}
      if (hepsi.length >= 6) break;
    }
    final l = hepsi.values.toList()
      ..sort((a, c) => _indirim(c).compareTo(_indirim(a)));
    return l.take(3).toList();
  }

  static double _indirim(ProductCard u) => u.special != null && u.special! < u.price ? 1 - u.special! / u.price : 0;
  static String _fiyat(ProductCard u) =>
      _indirim(u) > 0 ? '${_tl(u.special!)} (indirimde, ${_tl(u.price)} yerine)' : _tl(u.price);
  static String _kisa(String ad) => ad.length > 26 ? '${ad.substring(0, 25)}…' : ad;

  /// Güncel kampanyalar: panel duyuruları + vitrindeki indirimli ürünler
  Future<KbYanit> kampanyaListesi() async {
    var duyurular = const <String>[];
    var urunler = const <ProductCard>[];
    try {
      duyurular = await veri.kampanyaDuyurulari();
    } catch (_) {}
    try {
      urunler = (await veri.indirimliler()).take(5).toList();
    } catch (_) {}
    if (duyurular.isEmpty && urunler.isEmpty) {
      return const KbYanit('Şu an listelenen bir kampanya bulamadım. İstersen bir ürün için indirim gelince haber vereyim.',
          niyet: 'kampanya_yok_liste', secenekler: [KbSecenek('Haber ver', gonder: 'haber ver')]);
    }
    final b = StringBuffer('🏷️ kiyidanav.com güncel kampanyalar');
    for (final d in duyurular.take(3)) {
      b.write('\n• $d');
    }
    if (urunler.isNotEmpty) {
      b.write('\n\nİndirimdeki ürünler:');
      for (final u in urunler) {
        b.write('\n• ${u.name}: ${_fiyat(u)} (%${(_indirim(u) * 100).round()})');
      }
    }
    return KbYanit(b.toString(), niyet: 'kampanya_liste', secenekler: [
      for (final u in urunler.take(3)) KbSecenek('🛒 ${_kisa(u.name)}', gonder: '${u.id}', eylem: KbEylem.urunAc),
      const KbSecenek('Ürün için haber ver', gonder: 'haber ver'),
    ]);
  }

  // ------------------------------------------------------------------ blog
  /// Bilinmeyen soruyu kiyidanav.com/blog yazılarında arar
  Future<KbYanit?> blogdaAra(String n) async {
    List<KbBlogYazi> l;
    try {
      l = await veri.blog();
    } catch (_) {
      return null;
    }
    const bos = {'nasil', 'nedir', 'neden', 'hangi', 'icin', 'gibi', 'olur', 'mudur', 'midir', 'nerede', 'zaman', 'bana',
      'acaba', 'balik', 'yapilir', 'tutulur', 'olan', 'daha', 'kadar', 'nasıl'};
    final kelimeler =
        n.split(' ').where((k) => k.length >= 4 && !bos.contains(k)).map((k) => k.length > 6 ? k.substring(0, 6) : k).toSet();
    if (kelimeler.isEmpty) return null;
    KbBlogYazi? en;
    var enPuan = 0.0;
    for (final y in l) {
      final b = kbNorm(y.baslik), o = kbNorm(y.ozet);
      var p = 0.0;
      for (final k in kelimeler) {
        if (b.contains(k)) p += 2;
        if (o.contains(k)) p += 1;
      }
      if (p > enPuan) {
        enPuan = p;
        en = y;
      }
    }
    if (en == null || enPuan < 2) return null;
    final ozet = en.ozet.length > 220 ? '${en.ozet.substring(0, 220)}…' : en.ozet;
    return KbYanit('📖 Blogumuzda bu konuyla ilgili bir yazı buldum:\n"${en.baslik}"\n$ozet',
        niyet: 'blog',
        secenekler: [
          KbSecenek('Yazıyı oku', gonder: en.link, eylem: KbEylem.blogAc),
          const KbSecenek('Temsilciye bağlan', gonder: 'temsilci'),
        ]);
  }

  KbYanit _temsilciyeYonlendir(String once, {required String niyet}) {
    adim = KbAdim.temsilci;
    return KbYanit('$once $temsilciSorusu', niyet: niyet, secenekler: const [
      KbSecenek('Evet, bağlan', gonder: 'evet'),
      KbSecenek('Hayır', gonder: 'hayır'),
    ]);
  }

  // ------------------------------------------------------------------ kampanya
  Future<KbYanit> kampanyaKur(String urun) async {
    final ad = urun.length > 60 ? urun.substring(0, 60) : urun;
    List<ProductCard> l = const [];
    try {
      l = await veri.urunAra(ad);
    } catch (_) {}
    final indirimli = l.where((p) => p.special != null && p.special! < p.price).toList();
    final b = StringBuffer('Tamam! "$ad" için kampanya hatırlatıcısı kurdum. Bu üründe indirim görünce sana bildirim göndereceğim 🔔');
    if (indirimli.isNotEmpty) {
      b.write('\n\nŞu an indirimde olanlar da var:');
      for (final p in indirimli.take(3)) {
        b.write('\n• ${p.name}: ${_tl(p.price)} → ${_tl(p.special!)}');
      }
    } else if (l.isEmpty) {
      b.write('\n\nMağazada bu adla ürün bulamadım; adı biraz değiştirip yeniden yazabilirsin (ör. "olta makinesi").');
    }
    return KbYanit(b.toString(), niyet: 'kampanya_kur', kampanya: ad, secenekler: [
      KbSecenek('Ürünleri gör', gonder: ad, eylem: KbEylem.urunAra),
      const KbSecenek('Bildirimleri aç', eylem: KbEylem.bildirimIzni),
    ]);
  }

  static String _tl(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)} TL';

  // ------------------------------------------------------------------ mera
  /// Metindeki mera adını bulur (en uzun eşleşme); deniz meraları, nokta meralar, topluluk ve göller
  KbMera? _meraBul(String n) {
    final adaylar = <(String, KbMera)>[];
    for (final s in veri.denizMeralari()) {
      adaylar.add((kbNorm(s.name), KbMera(s.name, spot: s)));
    }
    for (final o in veri.topluluk()) {
      adaylar.add((kbNorm(o.ad), o.tur == MeraTuru.tuzlu ? KbMera(o.ad, spot: o.spot, oneri: o) : KbMera(o.ad, oneri: o)));
    }
    final fw = _golOnbellek;
    if (fw != null) {
      for (final p in fw.places) {
        adaylar.add((kbNorm(p.name), KbMera(p.name, gol: p)));
      }
    }
    KbMera? en;
    var enUzun = 0;
    for (final (ad, m) in adaylar) {
      if (ad.length < 3) continue;
      // Tam ad metinde geçiyor ("bugün kartaldayım" → kartal) ya da yazılan kelime adın başı
      final gecer = n.contains(ad) || (n.length >= 4 && ad.startsWith(n)) || _kokEslesir(n, ad);
      if (gecer && ad.length > enUzun) {
        en = m;
        enUzun = ad.length;
      }
    }
    return en;
  }

  /// "kartaldayim", "rivadayim", "sariyerde" gibi ekli yazımlar
  bool _kokEslesir(String n, String ad) {
    final ilk = ad.split(' ').first;
    if (ilk.length < 4) return false;
    for (final k in n.split(' ')) {
      if (k.length >= ilk.length && k.startsWith(ilk.substring(0, ilk.length - (ilk.length > 5 ? 1 : 0)))) return true;
    }
    return false;
  }

  FwData? _golOnbellek;
  Future<void> hazirla() async {
    try {
      _golOnbellek = await veri.tatliSu();
    } catch (_) {}
  }

  /// Seçilen meranın bugünkü özeti (yalnızca uygulama verisi)
  Future<String> meraOzeti(KbMera m) async {
    if (m.gol != null) return _golOzeti(m.gol!, m.oneri);
    if (m.spot == null && m.oneri != null) return _oneriOzeti(m.oneri!);
    final s = m.spot!;
    sonMera = s;
    final b = StringBuffer();
    try {
      final f = await veri.hafta(s);
      final r = f.now;
      final skor = FishingScore.compute(DateTime.now(),
          windKmh: r.effectiveWind,
          waveM: r.effectiveWave,
          pressureTrend: f.pressureTrend,
          rainMm: r.rainDay,
          currentKmh: r.currentKmh);
      b.write('📍 ${s.name} (${s.side.label})${s.nokta ? ' · 📌 nokta meran' : ''}\n');
      b.write('Bugün av verimliliği %$skor — ${FishingScore.label(skor)}. ${r.verdict}.\n');
      final p = <String>[
        if (r.windKmh != null) 'rüzgâr ${r.windKmh!.round()} km/s ${r.windFrom}',
        if (r.gustKmh != null) 'hamle ${r.gustKmh!.round()} km/s',
        if (r.strait) '${s.shelter} içi (akıntıya dikkat)' else if (r.waveM != null) 'dalga ${r.waveM!.toStringAsFixed(1)} m',
        if (r.seaC != null) 'su ${r.seaC!.round()}°',
        if (r.airC != null) 'hava ${r.airC!.round()}°',
      ];
      if (p.isNotEmpty) b.write('${_buyukHarf(p.join(', '))}.\n');
      final bugun = f.days.isNotEmpty ? f.days.first : null;
      if (bugun?.sunrise != null && bugun?.sunset != null) {
        b.write('En verimli saatler: sabah ${_saat(bugun!.sunrise!.subtract(const Duration(hours: 1)))}–'
            '${_saat(bugun.sunrise!.add(const Duration(hours: 1)))}, akşam ${_saat(bugun.sunset!.subtract(const Duration(hours: 1)))}–'
            '${_saat(bugun.sunset!.add(const Duration(hours: 1)))}.\n');
      }
    } catch (_) {
      b.write('📍 ${s.name} (${s.side.label})\nDeniz ve hava verisine şu an ulaşamadım.\n');
    }
    try {
      final k = await veri.kesit(s);
      if (k != null) {
        if (k.dip.isNotEmpty) b.write('Dip yapısı: ${k.dip}.\n');
        if (k.profile.isNotEmpty) {
          b.write('Kıyıdan derinlik: ${k.profile.map((e) => '${e.key} m → ~${e.value.round()} m').join(', ')} (tahmini).\n');
        }
        if (k.note.isNotEmpty) b.write('Not: ${k.note}\n');
      }
    } catch (_) {}
    final turler = bolgeTurleri(s).take(5).map((t) => baliklar[t]?.ad ?? t).toList();
    if (turler.isNotEmpty) b.write('Bu dönem kıyıdan en olası türler: ${turler.join(', ')}.');
    if (m.oneri?.onerenYazisi != null) b.write('\n${m.oneri!.onerenYazisi}.');
    return b.toString().trim();
  }

  String _golOzeti(FwPlace p, MeraOnerisi? o) {
    final fw = _golOnbellek;
    final turler = p.fish.map((k) => fw?.fish[k]?.name ?? k).toList();
    final b = StringBuffer('📍 ${p.name} — ${p.type}, ${p.province}${p.district.isNotEmpty ? ' / ${p.district}' : ''}\n');
    if (p.noFishing) b.write('⚠️ Bu suda avlanmak yasak (içme suyu vb.).\n');
    if (p.depth.isNotEmpty) b.write('Derinlik: ${p.depth}. ');
    if (p.area.isNotEmpty) b.write('Alan: ${p.area}.');
    b.write('\n');
    if (turler.isNotEmpty) b.write('Balıklar: ${turler.join(', ')}.\n');
    if (p.surroundings.isNotEmpty) b.write('Çevre: ${p.surroundings}${p.surroundingsNote.isNotEmpty ? ' (${p.surroundingsNote})' : ''}.\n');
    if (p.road.isNotEmpty) b.write('Ulaşım: ${p.road}.\n');
    if (p.tip.isNotEmpty) b.write('İpucu: ${p.tip}\n');
    if (p.warning.isNotEmpty) b.write('Uyarı: ${p.warning}');
    return b.toString().trim();
  }

  String _oneriOzeti(MeraOnerisi o) {
    final b = StringBuffer('📍 ${o.ad}${o.yer.isNotEmpty ? ' — ${o.yer}' : ''} (topluluk merası, ${o.tur.ad.toLowerCase()})\n');
    if (o.baliklar.isNotEmpty) b.write('Balıklar: ${o.baliklar.join(', ')}.\n');
    if (o.teknikler.isNotEmpty) b.write('Teknik: ${o.teknikler.join(', ')}.\n');
    if (o.dip.isNotEmpty) b.write('Dip: ${o.dip}.\n');
    if (o.derinlik.isNotEmpty) b.write('Derinlik: ${o.derinlik}.\n');
    if (o.zaman.isNotEmpty) b.write('Verimli zaman: ${o.zaman}.\n');
    if (o.notlar.isNotEmpty) b.write('${o.notlar}\n');
    if (o.onerenYazisi != null) b.write('${o.onerenYazisi}.');
    return b.toString().trim();
  }

  // ------------------------------------------------------------------ stil → en uygun mera
  /// Seçili meranın bölgesindeki meralar arasında bugünkü veriye göre bu stile en uygun olanlar
  Future<String> stilOnerisi(KbStil s) async {
    final merkez = sonMera ?? veri.secili;
    final adaylar = veri.denizMeralari().where((e) => e.side == merkez.side).toList();
    if (!adaylar.any((e) => e.ayni(merkez))) adaylar.insert(0, merkez);
    List<SpotForecast> l;
    try {
      l = await veri.simdi(adaylar.take(30).toList());
    } catch (_) {
      return '${s.ad} için şu an deniz verisine ulaşamadım. Genel ipucu: ${s.ipucu}';
    }
    if (l.isEmpty) return '${s.ad} için uygun veri bulamadım. Genel ipucu: ${s.ipucu}';
    final now = DateTime.now();
    double puan(SpotForecast f) {
      final skor = FishingScore.compute(now, windKmh: f.now.effectiveWind, waveM: f.now.effectiveWave, rainMm: f.now.rainDay);
      return skor * s.uygunluk(f.now) + (f.spot.ayni(merkez) ? 2 : 0);
    }

    l.sort((a, b) => puan(b).compareTo(puan(a)));
    final en = l.first;
    final r = en.now;
    final skor = FishingScore.compute(now, windKmh: r.effectiveWind, waveM: r.effectiveWave, rainMm: r.rainDay);
    final neden = <String>[
      'rüzgâr ${r.effectiveWind.round()} km/s',
      if (r.strait) '${en.spot.shelter} içi, akıntılı' else if (r.waveM != null) 'dalga ${r.effectiveWave.toStringAsFixed(1)} m',
    ];
    final b = StringBuffer('🎯 ${s.ad} için bugün ${merkez.side.label} bölgesinde en uygun mera: ${en.spot.name}'
        '${en.spot.nokta ? ' (nokta meran)' : ''} — av verimliliği %$skor, ${neden.join(', ')}.');
    final digerleri = l.skip(1).take(2).map((f) => f.spot.name).toList();
    if (digerleri.isNotEmpty) b.write('\nAlternatif: ${digerleri.join(', ')}.');
    if (s.uygunluk(r) < 0.5) b.write('\n⚠️ Koşullar bu stil için bugün pek uygun değil; korunaklı bir nokta seç ya da stili değiştir.');
    final hedef = s.turler.where((t) => baliklar.containsKey(t) && avIhtimali(balikBolgesi(en.spot), t, now) > 0).map((t) => baliklar[t]!.ad).take(3).toList();
    if (hedef.isNotEmpty) b.write('\nHedef türler: ${hedef.join(', ')}.');
    b.write('\nİpucu: ${s.ipucu}');
    sonMera = en.spot;
    return b.toString();
  }

  // ------------------------------------------------------------------ serbest sorular
  Future<KbYanit?> _serbest(String n) async {
    if (_icerir(n, ['merhaba', 'selam', 'gunaydin', 'iyi aksamlar', 'mrb', 'slm']) && n.split(' ').length <= 3) {
      return const KbYanit('Merhaba! 👋 Meralar, deniz durumu, balık türleri ve ürünler hakkında sorabilirsin.', niyet: 'selam');
    }
    if (_icerir(n, ['tesekkur', 'sagol', 'eyvallah', 'sag ol'])) {
      return const KbYanit('Rica ederim, rastgele! 🎣', niyet: 'tesekkur');
    }
    if (_icerir(n, ['ne yapabilirsin', 'yardim', 'neler biliyorsun', 'nasil kullan'])) {
      return const KbYanit(
          'Şunları yapabilirim:\n• Meranın bugünkü av verimliliği, rüzgâr, dalga, su sıcaklığı ve dip yapısı\n'
          '• Stiline (LRF, spin, surf…) göre bugün en uygun merayı bulmak\n• Bölgede hangi balığın çıktığı, yasal boy ve yasaklar\n'
          '• Ürün kampanyası için hatırlatma kurmak\n• Tatlı su göl ve barajları\nBilemediğimde seni müşteri temsilcimize bağlarım.',
          niyet: 'yardim');
    }
    // Yemli çinekop / lüfer avı → mantarlı takım + tekne
    if (cinekopSorusu(n)) return cinekopYaniti();
    if (_icerir(n, ['tekne', 'balik turu', 'charter'])) {
      adim = KbAdim.tekneSor;
      return const KbYanit('Çinekop, lüfer ve palamutta tekneden avlanmak kıyıya göre çok daha verimli. '
          'Ekibimizle tekne avı ayarlayabiliriz. Tekne avına çıkmak ister misiniz?', niyet: 'tekne', secenekler: _tekneSecenek);
    }
    // Mera adı geçiyorsa
    final m = _meraBul(n);
    if (m != null && !_icerir(n, ['kargo', 'siparis'])) {
      final ozet = await meraOzeti(m);
      return KbYanit(ozet, niyet: 'mera', spot: m.spot, secenekler: [
        if (m.spot != null) const KbSecenek('Mera bilgisini aç', eylem: KbEylem.meraBilgisiAc),
        const KbSecenek('Stilime göre mera öner', gonder: 'hangi stil'),
      ]);
    }
    if (_icerir(n, ['hangi stil', 'stilime', 'nerede tutarim', 'nereye gideyim', 'en iyi mera', 'hangi meraya'])) {
      adim = KbAdim.stil;
      return const KbYanit('Hangi stilde avlanıyorsun?', niyet: 'stil_sor', secenekler: _stilSecenekleri);
    }
    if (ekipmanSorusu(n)) return ekipmanYaniti(n);
    final stil = kbStilBul(n);
    if (stil != null) {
      sonStil = stil;
      return KbYanit(await stilOnerisi(stil), niyet: 'stil_${kbNorm(stil.ad).replaceAll(' ', '_')}', spot: sonMera, secenekler: [
        KbSecenek('${stil.ad} ekipmanı', gonder: '${stil.ad} ekipmanı'),
        const KbSecenek('Mera bilgisini aç', eylem: KbEylem.meraBilgisiAc),
      ]);
    }
    // Hava / deniz durumu (seçili meraya göre)
    if (_icerir(n, ['ruzgar', 'dalga', 'hava', 'deniz', 'su sicak', 'basinc', 'yagmur', 'firtina', 'bugun nasil', 'verim'])) {
      final s = sonMera ?? veri.secili;
      return KbYanit(await meraOzeti(KbMera(s.name, spot: s)), niyet: 'hava', spot: s,
          secenekler: const [KbSecenek('Mera bilgisini aç', eylem: KbEylem.meraBilgisiAc)]);
    }
    // Balık türü
    for (final e in baliklar.entries) {
      final ad = kbNorm(e.value.ad.split(RegExp(r'[ (/]')).first);
      if (ad.length >= 4 && n.contains(ad)) {
        final b = e.value;
        final s = sonMera ?? veri.secili;
        final now = DateTime.now();
        final bolge = balikBolgesi(s);
        final ihtimal = avIhtimali(bolge, e.key, now);
        final sb = StringBuffer('🐟 ${b.ad}\nTeknik: ${b.teknik}.\nYasal asgari boy: ${b.boy} · Limit: ${b.limit}.\n'
            'Kıyıdan tipik mesafe: ${b.mesafeMin}–${b.mesafeMax} m.');
        if (b.yasakta(now)) {
          sb.write('\n⚠️ Şu an av yasağında (${b.yasakMetni}).');
        } else if (b.yasak != null) {
          sb.write('\nAv yasağı: ${b.yasakMetni}.');
        }
        sb.write(ihtimal >= 1
            ? '\n$bolge bölgesinde şu dönem kıyıdan sık çıkıyor.'
            : ihtimal > 0
                ? '\n$bolge bölgesinde ara sıra çıkıyor; sezonu ${b.aylar.map(_ayKisa).join(', ')}.'
                : '\n$bolge bölgesinde kıyıdan pek beklenmiyor.');
        if (b.not.isNotEmpty) sb.write('\n${b.not}');
        return KbYanit(sb.toString(), niyet: 'balik_${e.key}');
      }
    }
    if (_icerir(n, ['hangi balik', 'ne cikiyor', 'ne tutulur', 'bu ay', 'sezon'])) {
      final s = sonMera ?? veri.secili;
      final l = bolgeTurleri(s).take(6).map((t) => baliklar[t]?.ad ?? t).join(', ');
      return KbYanit('${balikBolgesi(s)} bölgesinde (${s.name}) şu dönem kıyıdan en olası türler: $l.', niyet: 'bu_ay', spot: s);
    }
    if (_icerir(n, ['dugum'])) {
      return const KbYanit('Balıkçı düğümleri uygulamada adım adım anlatılıyor.', niyet: 'dugum',
          secenekler: [KbSecenek('Düğümleri aç', eylem: KbEylem.dugumler)]);
    }
    if (_icerir(n, ['mera oner', 'mera ekle', 'yeni mera'])) {
      return const KbYanit('Bildiğin bir merayı önerebilirsin; yönetici onayından sonra herkes görür. İstersen adınla yayınlanır.',
          niyet: 'mera_oner', secenekler: [KbSecenek('Mera öner', eylem: KbEylem.meraOner), KbSecenek('Topluluk meraları', eylem: KbEylem.toplulukMeralari)]);
    }
    if (_icerir(n, ['gol', 'baraj', 'tatli su', 'gölet', 'golet'])) {
      return const KbYanit('Tatlı su göl ve barajlarını Mera Bilgisi › Tatlı su meraları bölümünde bulabilirsin. Göl adını yazarsan özetlerim.',
          niyet: 'tatli');
    }
    if (_icerir(n, ['kargo', 'ucretsiz kargo', 'gonderim'])) {
      return KbYanit('${AppConfig.freeShippingLimit.round()} TL ve üzeri siparişlerde kargo ücretsiz; altındaki siparişlerde kargo ücretinin '
          'yarısı bizden, yalnızca ${AppConfig.shippingFee.round()} TL (kesin tutarı ödeme sayfası gösterir). Sipariş durumunu Hesabım › Siparişlerim\'den görebilirsin.',
          niyet: 'kargo');
    }
    if (_icerir(n, ['siparis', 'iade', 'degisim', 'fatura', 'odeme', 'kart', 'garanti', 'bozuk', 'eksik'])) {
      return _temsilciyeYonlendir('Sipariş, iade ve ödeme konularında müşteri temsilcimiz en doğru yanıtı verir.', niyet: 'siparis');
    }
    if (_icerir(n, ['urun', 'fiyat', 'stok', 'makine', 'kamis', 'misina', 'yem', 'olta'])) {
      return KbYanit('Mağazada arayabilirim. İstersen bu ürün için kampanya hatırlatıcısı da kurarım.', niyet: 'urun',
          secenekler: [KbSecenek('Mağazada ara', gonder: n, eylem: KbEylem.urunAra), const KbSecenek('Kampanya kur', gonder: 'kampanya')]);
    }
    return null;
  }

  // ------------------------------------------------------------------ yardımcılar
  static bool _icerir(String n, List<String> l) => l.any((k) => n.contains(kbNorm(k)));
  static bool _evet(String n) => RegExp(r'^(evet|olur|tamam|isterim|baglan|e|tabi|tabii)( |$)').hasMatch(n);
  static bool _hayir(String n) => RegExp(r'^(hayir|yok|istemem|gerek yok|sonra|h)( |$)').hasMatch(n);
  static String _saat(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _buyukHarf(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  static String _ayKisa(int a) => const ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'][a];
}
