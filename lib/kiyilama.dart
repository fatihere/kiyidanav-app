/// Kıyılama: küçük ve büyük balığın bugün kıyıdan kaç metrede olduğu, ona uygun disiplin ve yem ağırlığı.
/// Saf Dart — raporda, "Balık kaç metrede" kartında ve bildirimlerde AYNI hesap kullanılır,
/// böylece ekrandaki sayılar ve öneriler birbirini tutar.
library;

import 'dart:math' as math;

import 'balik_bul.dart';

/// Rüzgârın kıyıya göre yönü
enum RuzgarKiyi { denizden, karadan, paralel, bilinmiyor }

RuzgarKiyi ruzgarKiyi(double? kiyiYon, double? ruzgarGeldigi, {double aci = 60}) {
  if (kiyiYon == null || ruzgarGeldigi == null) return RuzgarKiyi.bilinmiyor;
  if (kiyiyaVuruyor(kiyiYon, ruzgarGeldigi, aci: aci)) return RuzgarKiyi.denizden;
  if (kiyidanEsiyor(kiyiYon, ruzgarGeldigi, aci: aci)) return RuzgarKiyi.karadan;
  return RuzgarKiyi.paralel;
}

class Kiyilama {
  final int kucukMin, kucukMax; // küçük balık (karagöz, istavrit, isparoz…)
  final int buyukMin, buyukMax; // büyük balık (levrek, çupra, lüfer…)
  final int geceMin, geceMax; // gün batımından sonra büyük balık
  final int sev; // ilk belirgin derinleşmenin başladığı mesafe
  final String disiplin; // LRF / Spin / Surfcasting
  final String gram; // "30–60 g"
  final bool agirTakim; // rüzgâr/dalga yüzünden bir kademe ağır
  final String neden;

  const Kiyilama({
    required this.kucukMin,
    required this.kucukMax,
    required this.buyukMin,
    required this.buyukMax,
    required this.geceMin,
    required this.geceMax,
    required this.sev,
    required this.disiplin,
    required this.gram,
    required this.agirTakim,
    required this.neden,
  });

  String get kucuk => '$kucukMin–$kucukMax m';
  String get buyuk => '$buyukMin–$buyukMax m';
  String get gece => '$geceMin–$geceMax m';
  String get takim => '$disiplin · $gram';
}

const _gramlar = ['3–10 g', '15–30 g', '30–60 g', '100–150 g kurşun'];

/// [profil]: (kıyıdan m, derinlik m) kesiti; [bant]: ölçümlerin ortak yorumundan gelen bugünkü bant (varsa)
Kiyilama kiyilamaHesapla({
  required List<MapEntry<int, double>> profil,
  Bant? bant,
  double? kiyiYon,
  double? ruzgarGeldigi,
  double ruzgarKmh = 0,
  double dalgaM = 0,
  bool korunakli = false,
}) {
  // 1) Meranın yapısı: şev nerede? (kesit yoksa derinliğin ~5 m'yi geçtiği yer, o da yoksa 25 m)
  final s = sevBul(profil);
  var sev = s?.bas ?? 0;
  if (sev <= 0) {
    final p = [...profil]..sort((a, b) => a.key.compareTo(b.key));
    final d5 = p.where((e) => e.value >= 5);
    sev = d5.isNotEmpty ? d5.first.key : 25;
  }
  sev = sev.clamp(5, 120).toInt();

  // 2) Bugünün koşulları
  final rk = ruzgarKiyi(kiyiYon, ruzgarGeldigi);
  var bMin = sev.toDouble(), bMax = sev + 40.0;
  final nedenler = <String>[];
  if (rk == RuzgarKiyi.denizden && dalgaM >= 0.3 && dalgaM <= 1.2) {
    bMin = sev * 0.5;
    bMax = sev + 25.0;
    nedenler.add('denizden esen rüzgâr ve köpük yemi kıyıya taşıyor');
  } else if (rk == RuzgarKiyi.karadan && ruzgarKmh > 12) {
    bMin = sev + 10.0;
    bMax = sev + 60.0;
    nedenler.add('kıyıdan esen rüzgâr yüzey suyunu açığa itiyor');
  } else if (dalgaM < 0.2 && !korunakli) {
    bMin = sev + 5.0;
    bMax = sev + 50.0;
    nedenler.add('durgun ve berrak suda balık şevin ötesinde');
  } else {
    nedenler.add('büyük balık ilk derinleşmenin (şevin) önünde bekler');
  }
  // Ölçümlerin ortak bandı (basınç, bulut, dalga, uydu) ile birleştir: iki yorumun ortalaması
  if (bant != null) {
    bMin = (bMin + bant.min) / 2;
    bMax = (bMax + bant.max) / 2;
  }
  double y5(double v) => (v / 5).round() * 5.0;
  final buyukMin = math.max(5, y5(bMin)).toInt();
  final buyukMax = math.min(200, math.max(buyukMin + 10, y5(bMax).toInt()));
  final kucukMax = math.max(8, math.min(buyukMin, (sev * 0.8).round()));
  final geceMin = math.max(3, (buyukMin * 0.4).round());
  final geceMax = math.min(200, sev + 10);

  // 3) Bu mesafeye uygun takım
  final agir = (ruzgarKmh > 20 && rk != RuzgarKiyi.karadan) || dalgaM > 0.8;
  var i = buyukMax <= 25 ? 0 : (buyukMax <= 50 ? 1 : (buyukMax <= 80 ? 2 : 3));
  if (agir && i < 3) i++;
  final disiplin = buyukMax <= 30 ? 'LRF' : (buyukMax <= 60 ? 'Spin' : 'Surfcasting');
  return Kiyilama(
    kucukMin: 2,
    kucukMax: kucukMax,
    buyukMin: buyukMin,
    buyukMax: buyukMax,
    geceMin: geceMin,
    geceMax: math.max(geceMin + 5, geceMax),
    sev: sev,
    disiplin: disiplin,
    gram: _gramlar[i],
    agirTakim: agir,
    neden: '${nedenler.first[0].toUpperCase()}${nedenler.first.substring(1)}.',
  );
}

/// Rapor başlığı: verimlilik puanı ile rüzgâr/dalga durumunu tek cümlede birleştirir
/// (ör. puan "Zayıf" iken "kıyıdan atış için ideal" demez).
String raporHukmu({required int puan, required double ruzgar, required double dalga, required Kiyilama k, bool yagisli = false}) {
  String v;
  if (ruzgar >= 40 || dalga >= 1.8) {
    v = 'Fırtınalı — bugün kıyıdan uzak dur';
  } else if (ruzgar >= 28 || dalga >= 1.0) {
    v = 'Sert — korunaklı bir kıyı seç, ${k.gram} ile';
  } else if (k.agirTakim || ruzgar >= 18 || dalga >= 0.5) {
    v = puan >= 50 ? 'Uygun, biraz ağır takım tercih et (${k.gram})' : 'Verim düşük; ağır takımla kısa bir seans dene (${k.gram})';
  } else {
    v = puan >= 50 ? 'Kıyıdan atış için ideal (${k.takim})' : 'Hava sakin ama verim düşük; ince takım ve sabır (${k.takim})';
  }
  return yagisli ? '$v · yağışlı' : v;
}
