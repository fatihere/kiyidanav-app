/// "Balığı bul" modüllerinin hesapları — saf Dart (Flutter yok), birim testleriyle doğrulanır.
/// Aynı kurallar web sitesinde (mera-bilgisi.php) JavaScript ile uygulanır.
library;

import 'dart:math' as math;

import 'olcum_yorum.dart';

// ======================================================================= Mesafe
/// Bir mesafe bandı (kıyıdan metre)
class Bant {
  final double min;
  final double max;
  const Bant(this.min, this.max);
  double get orta => (min + max) / 2;
}

/// Ölçüm yorumlarındaki mesafe metinlerini sayısal banda çevirir
Bant? mesafeBandi(String mesafe) {
  if (mesafe.isEmpty) return null;
  if (mesafe == Mesafe.yakin) return const Bant(2, 40);
  if (mesafe == Mesafe.yakinOrta) return const Bant(10, 60);
  if (mesafe == Mesafe.orta) return const Bant(30, 100);
  if (mesafe == Mesafe.uzak) return const Bant(80, 200);
  return null;
}

class MesafeGirdi {
  final OlcumYorum yorum;
  final double agirlik;
  const MesafeGirdi(this.yorum, this.agirlik);
}

class MesafeHukmu {
  final Bant bant;
  final String etiket; // Yakın, Yakın–orta, Orta, Uzak/derin
  final String neden; // "Basınç düşüyor, gökyüzü kapalı…"
  const MesafeHukmu(this.bant, this.etiket, this.neden);
}

/// Ağırlıklı ortalama: her ölçümün önerdiği bandın alt/üst sınırı ağırlıkla birleştirilir
MesafeHukmu? mesafeHukmu(List<MesafeGirdi> girdiler) {
  var tw = 0.0, mn = 0.0, mx = 0.0;
  final nedenler = <(double, String)>[];
  for (final g in girdiler) {
    final b = mesafeBandi(g.yorum.mesafe);
    if (b == null || g.agirlik <= 0) continue;
    tw += g.agirlik;
    mn += b.min * g.agirlik;
    mx += b.max * g.agirlik;
    final kisa = g.yorum.durum.split(':').first.trim();
    nedenler.add((g.agirlik, '${g.yorum.baslik.toLowerCase()} ${kisa.toLowerCase()}'));
  }
  if (tw == 0) return null;
  // 5 m'ye yuvarla
  double y5(double v) => (v / 5).round() * 5.0;
  final bant = Bant(math.max(2.0, y5(mn / tw)), math.max(5.0, y5(mx / tw)));
  final o = bant.orta;
  final etiket = o < 30 ? 'Yakın' : (o < 55 ? 'Yakın–orta' : (o < 100 ? 'Orta' : 'Uzak/derin'));
  nedenler.sort((a, b) => b.$1.compareTo(a.$1));
  final neden = nedenler.take(3).map((e) => e.$2).join(', ');
  return MesafeHukmu(bant, etiket, neden.isEmpty ? '' : '${neden[0].toUpperCase()}${neden.substring(1)}.');
}

// ======================================================================= Kıyı yönü
/// İki yön arasındaki en küçük açı (0–180°)
double aciFarki(double a, double b) {
  final d = ((a - b) % 360 + 540) % 360 - 180;
  return d.abs();
}

/// Rüzgâr kıyıya vuruyor mu? [kiyiYon]: kıyıdan denize bakış yönü; [ruzgarGeldigi]: rüzgârın geldiği yön
bool kiyiyaVuruyor(double kiyiYon, double ruzgarGeldigi, {double aci = 60}) => aciFarki(kiyiYon, ruzgarGeldigi) <= aci;

/// Rüzgâr kıyıdan açığa mı esiyor? (geldiği yön kıyının arkası)
bool kiyidanEsiyor(double kiyiYon, double ruzgarGeldigi, {double aci = 60}) =>
    aciFarki((kiyiYon + 180) % 360, ruzgarGeldigi) <= aci;

const yonAdlari8 = ['kuzey', 'kuzeydoğu', 'doğu', 'güneydoğu', 'güney', 'güneybatı', 'batı', 'kuzeybatı'];
String yonAdi(double d) => yonAdlari8[((d % 360 + 360) % 360 / 45).round() % 8];

/// Yön adlarının Türkçe halleri: "kuzeye", "kuzeyden", "kuzeyde"
const _yonE = {'kuzey': 'kuzeye', 'güney': 'güneye'};
const _yonDen = {'kuzey': 'kuzeyden', 'güney': 'güneyden'};
const _yonDe = {'kuzey': 'kuzeyde', 'güney': 'güneyde'};
String yonE(String ad) => _yonE[ad] ?? (ad.isEmpty ? '' : '${ad}ya');
String yonDen(String ad) => _yonDen[ad] ?? (ad.isEmpty ? '' : '${ad}dan');
String yonDe(String ad) => _yonDe[ad] ?? (ad.isEmpty ? '' : '${ad}da');

// ======================================================================= Kesit ve şev
class Sev {
  final int bas; // kıyıdan metre
  final int son;
  final double artis; // 50 m başına derinlik artışı
  const Sev(this.bas, this.son, this.artis);
}

/// Profilde 50 m başına derinlik artışı [esik] metreyi geçen ilk aralık
Sev? sevBul(List<MapEntry<int, double>> profil, {double esik = 5}) {
  final p = [...profil]..sort((a, b) => a.key.compareTo(b.key));
  for (var i = 1; i < p.length; i++) {
    final dx = (p[i].key - p[i - 1].key).toDouble();
    if (dx <= 0) continue;
    final artis = (p[i].value - p[i - 1].value) / (dx / 50);
    if (artis >= esik) return Sev(p[i - 1].key, p[i].key, artis);
  }
  return null;
}

// ======================================================================= Berraklık
/// 0 = berrak, 1 = hafif bulanık, 2 = bulanık
int berraklikSinifi(double kd490, {double berrak = 0.08, double bulanik = 0.25}) =>
    kd490 < berrak ? 0 : (kd490 > bulanik ? 2 : 1);

const berraklikAd = ['Berrak', 'Hafif bulanık', 'Bulanık'];
const berraklikOneri = [
  'Uzun atış, ince floro lider, doğal ve şeffaf renkler.',
  'Orta mesafe; doğal tonlar, hafif parıltı.',
  'Yakın mesafe; titreşimli, sesli ve kokulu yemler; koyu ya da parlak renk.',
];
const berraklikRenkler = [
  [('Gümüş', 0xFFC9D1D6), ('Sardalya', 0xFF8FA9B8), ('Şeffaf', 0xFFE8F1F2)],
  [('Gümüş', 0xFFC9D1D6), ('Doğal yeşil', 0xFF6E8B5A), ('Pembe', 0xFFF48FB1)],
  [('Chartreuse', 0xFFB8E02A), ('Mor sırt', 0xFF5B3A8C), ('Siyah', 0xFF222222)],
];

/// Kd490'dan yaklaşık görüş derinliği (Secchi ≈ 1,7 / Kd)
double gorusMetre(double kd490) => kd490 <= 0 ? 0 : 1.7 / kd490;

// ======================================================================= Solunar (ay konumu)
/// Düşük hassasiyetli ay konumu (~1°): solunar periyotları için yeterli
class AyKonum {
  /// [t] UTC zamanı → (sağ açıklık, dik açıklık) derece
  static (double ra, double dec) ekvator(DateTime t) {
    final d = t.toUtc().difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400.0;
    double r(double x) => x * math.pi / 180;
    final l = 218.316 + 13.176396 * d;
    final m = 134.963 + 13.064993 * d;
    final f = 93.272 + 13.229350 * d;
    final lam = r(l + 6.289 * math.sin(r(m)));
    final bet = r(5.128 * math.sin(r(f)));
    final eps = r(23.439 - 0.0000004 * d);
    final ra = math.atan2(math.sin(lam) * math.cos(eps) - math.tan(bet) * math.sin(eps), math.cos(lam));
    final dec = math.asin(math.sin(bet) * math.cos(eps) + math.cos(bet) * math.sin(eps) * math.sin(lam));
    return (ra * 180 / math.pi, dec * 180 / math.pi);
  }

  /// Ayın ufuktan yüksekliği (derece)
  static double yukseklik(DateTime t, double lat, double lon) {
    final d = t.toUtc().difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400.0;
    final (ra, dec) = ekvator(t);
    final gmst = 280.46061837 + 360.98564736629 * d;
    final ha = (gmst + lon - ra) * math.pi / 180;
    final la = lat * math.pi / 180, de = dec * math.pi / 180;
    return math.asin(math.sin(la) * math.sin(de) + math.cos(la) * math.cos(de) * math.cos(ha)) * 180 / math.pi;
  }
}

class SolunarPeriyot {
  final DateTime orta;
  final bool buyuk; // büyük: ay tepede / ayaklar altında; küçük: ay doğuşu / batışı
  final String ad;
  final Duration sure;
  const SolunarPeriyot(this.orta, this.buyuk, this.ad, this.sure);
  DateTime get bas => orta.subtract(sure ~/ 2);
  DateTime get son => orta.add(sure ~/ 2);
}

/// Yerel günün (gece yarısından gece yarısına) solunar periyotları
List<SolunarPeriyot> solunar(DateTime gun, double lat, double lon, {double buyukSaat = 2, double kucukSaat = 1}) {
  final bas = DateTime(gun.year, gun.month, gun.day);
  const adim = Duration(minutes: 10);
  final yuks = <double>[];
  final zam = <DateTime>[];
  for (var t = bas.subtract(adim); t.isBefore(bas.add(const Duration(hours: 24, minutes: 11))); t = t.add(adim)) {
    zam.add(t);
    yuks.add(AyKonum.yukseklik(t, lat, lon));
  }
  final out = <SolunarPeriyot>[];
  final bSure = Duration(minutes: (buyukSaat * 60).round());
  final kSure = Duration(minutes: (kucukSaat * 60).round());
  bool gunde(DateTime t) => !t.isBefore(bas) && t.isBefore(bas.add(const Duration(days: 1)));
  for (var i = 1; i < yuks.length - 1; i++) {
    final t = zam[i];
    if (!gunde(t)) continue;
    if (yuks[i] > yuks[i - 1] && yuks[i] >= yuks[i + 1]) out.add(SolunarPeriyot(t, true, 'Ay tepede', bSure));
    if (yuks[i] < yuks[i - 1] && yuks[i] <= yuks[i + 1]) out.add(SolunarPeriyot(t, true, 'Ay ayak altında', bSure));
    const h0 = 0.125; // ay doğuş/batış yüksekliği (paralaks dahil yaklaşık)
    if (yuks[i - 1] < h0 && yuks[i] >= h0) out.add(SolunarPeriyot(t, false, 'Ay doğuşu', kSure));
    if (yuks[i - 1] >= h0 && yuks[i] < h0) out.add(SolunarPeriyot(t, false, 'Ay batışı', kSure));
  }
  out.sort((a, b) => a.orta.compareTo(b.orta));
  return out;
}

/// Gece aydınlığı: 0 (zifiri) – 1 (dolunay, açık gökyüzü)
double geceAydinligi(double ayIsigi, int? bulut) => (ayIsigi * (1 - (bulut ?? 0) / 100 * 0.85)).clamp(0.0, 1.0);

String geceAydinligiAd(double v) => v < 0.15 ? 'Karanlık' : (v < 0.45 ? 'Loş' : (v < 0.75 ? 'Aydınlık' : 'Çok aydınlık'));

String geceAydinligiOneri(double v) => v < 0.15
    ? 'Fosforlu ve sesli yemler; ışıklı iskele ve lamba altları öne çıkar.'
    : (v < 0.45
        ? 'Koyu silüetli yemler; ışık kenarlarını tara.'
        : 'Balık ay ışığında yüzeye yakın av yapar; doğal renk, yavaş yüzey sunumu.');

// ======================================================================= Deniz seviyesi
class SeviyeDegisim {
  final double cm; // + yükseliyor, − alçalıyor
  final DateTime bas;
  final DateTime son;
  const SeviyeDegisim(this.cm, this.bas, this.son);
}

/// Önümüzdeki [saat] içindeki en büyük tek yönlü değişim (m cinsinden seriden cm)
SeviyeDegisim? seviyeDegisim(List<DateTime> zaman, List<double?> seviyeM, DateTime simdi, {int saat = 12}) {
  final i0 = zaman.indexWhere((t) => !t.isBefore(DateTime(simdi.year, simdi.month, simdi.day, simdi.hour)));
  if (i0 < 0) return null;
  final son = math.min(zaman.length, i0 + saat + 1);
  SeviyeDegisim? en;
  for (var a = i0; a < son; a++) {
    final va = a < seviyeM.length ? seviyeM[a] : null;
    if (va == null) continue;
    for (var b = a + 1; b < son; b++) {
      final vb = b < seviyeM.length ? seviyeM[b] : null;
      if (vb == null) continue;
      final cm = (vb - va) * 100;
      if (en == null || cm.abs() > en.cm.abs()) en = SeviyeDegisim(cm, zaman[a], zaman[b]);
    }
  }
  return en;
}
