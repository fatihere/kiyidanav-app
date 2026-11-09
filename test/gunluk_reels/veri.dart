// Günlük Reels — veri: uygulamanın rapor ekranıyla AYNI hesap (report_screen._load + FishingScore + bugunkuKiyilama)
import 'dart:math' as math;

import 'package:kiyidanav/api.dart';
import 'package:kiyidanav/balik_rehberi.dart' show baliklar, bolgeTurleri;
import 'package:kiyidanav/catches.dart';
import 'package:kiyidanav/kiyilama.dart';
import 'package:kiyidanav/mera.dart';
import 'package:kiyidanav/modul_kartlari.dart' show bugunkuKiyilama;
import 'package:kiyidanav/sea.dart';
import 'package:kiyidanav/solunar.dart';

class MeraGunu {
  final Spot spot;
  final SpotForecast f;
  final int puan;
  final Kiyilama k;
  final String hukum;
  final MeraInfo? info;
  final List<String> turler;
  MeraGunu(this.spot, this.f, this.puan, this.k, this.hukum, this.info, this.turler);

  SeaReport get r => f.now;
  bool get firtina => r.effectiveWind >= 40 || r.effectiveWave >= 1.8;
  bool get sert => r.effectiveWind >= 28 || r.effectiveWave >= 1.0;

  Map<String, Object?> json() => {
        'mera': spot.name,
        'yaka': spot.side.label,
        'puan': puan,
        'ruzgar_kmh': r.effectiveWind.round(),
        'ruzgar_yon': r.windFrom,
        'dalga_m': double.parse(r.effectiveWave.toStringAsFixed(1)),
        'su_c': r.seaC?.round(),
        'bulut': r.cloud,
        'kucuk': k.kucuk,
        'buyuk': k.buyuk,
        'gece': k.gece,
        'takim': k.takim,
        'neden': k.neden,
        'hukum': hukum,
        'turler': turler,
        'kesit': info?.profile.map((e) => [e.key, e.value]).toList() ?? [],
      };
}

Future<MeraGunu?> meraGunu(Spot s, DateTime now) async {
  try {
    final fx = Api.config.features;
    final sat = fx.satellite
        ? SatService.of(s.lat, s.lon).timeout(const Duration(seconds: 10), onTimeout: () => null)
        : Future<SatInfo?>.value(null);
    final catches = fx.catchList
        ? CatchService.forSpot(s.key).timeout(const Duration(seconds: 8), onTimeout: () => const <CatchReport>[])
        : Future<List<CatchReport>>.value(const []);
    final info = MeraService.of(s).timeout(const Duration(seconds: 8), onTimeout: () => null);
    final f = await SeaService.fetchWeek(s);
    final sa = await sat, ca = await catches, inf = await info;
    final puan = FishingScore.compute(now,
        windKmh: f.now.effectiveWind,
        waveM: f.now.effectiveWave,
        pressureTrend: f.pressureTrend,
        rainMm: f.now.rainDay,
        currentKmh: f.now.currentKmh,
        recentCatches: ca.length,
        sstChange5d: sa?.sstChange5d,
        chlChangePct: sa?.chlChangePct);
    final k = bugunkuKiyilama(f, sa, now, inf);
    final hukum = raporHukmu(puan: puan, ruzgar: f.now.effectiveWind, dalga: f.now.effectiveWave, k: k, yagisli: f.now.rainy);
    final turler = bolgeTurleri(s, now).take(3).map((e) => (baliklar[e]?.ad ?? e).split(' / ').first).toList();
    return MeraGunu(s, f, puan, k, hukum, inf, turler);
  } catch (e) {
    // ignore: avoid_print
    print('atlandı: ${s.name}: $e');
    return null;
  }
}

/// Günün 3 merası — her gün farklı: kıyıdan avlanılabilir (en iyi hava sınıfındaki) meralar arasından,
/// tarihe bağlı tohumla, puana göre ağırlıklı RASTGELE seçilir; her yakadan en çok 2. Aynı gün yeniden üretilirse
/// aynı meralar çıkar (tohum = tarih). Seçilenler puana göre sıralanır (1. mera = en yüksek puan).
List<MeraGunu> secim(List<MeraGunu> l, DateTime gun) {
  if (l.length <= 3) return [...l]..sort((a, b) => b.puan.compareTo(a.puan));
  int sinif(MeraGunu m) => m.firtina ? 2 : (m.sert ? 1 : 0);
  final gunNo = gun.difference(DateTime(gun.year)).inDays;
  final rnd = math.Random(gun.year * 1000 + gunNo);
  // aday havuzu: en iyi hava sınıfı; 3'ten azsa bir sonraki sınıf da eklenir
  final siniflar = l.map(sinif).toSet().toList()..sort();
  final aday = <MeraGunu>[];
  for (final s in siniflar) {
    aday.addAll(l.where((m) => sinif(m) == s));
    if (aday.length >= 6) break;
  }
  final enDusuk = aday.map((m) => m.puan).reduce(math.min);
  final out = <MeraGunu>[];
  final yaka = <Side, int>{};
  while (out.length < 3 && aday.isNotEmpty) {
    final uygun = aday.where((m) => (yaka[m.spot.side] ?? 0) < 2).toList();
    final havuz = uygun.isEmpty ? aday : uygun;
    final agirlik = havuz.map((m) => (m.puan - enDusuk + 15).toDouble()).toList();
    var r = rnd.nextDouble() * agirlik.reduce((a, b) => a + b);
    var i = 0;
    while (i < havuz.length - 1 && r > agirlik[i]) {
      r -= agirlik[i];
      i++;
    }
    final m = havuz[i];
    out.add(m);
    aday.remove(m);
    yaka[m.spot.side] = (yaka[m.spot.side] ?? 0) + 1;
  }
  return out..sort((a, b) => b.puan.compareTo(a.puan));
}
