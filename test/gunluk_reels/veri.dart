// Günlük Reels — veri: uygulamanın rapor ekranıyla AYNI hesap (report_screen._load + FishingScore + bugunkuKiyilama)
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

/// Günün 3 merası: önce kıyıdan avlanılabilir olanlar, sonra puan; her yakadan en çok 2
List<MeraGunu> secim(List<MeraGunu> l) {
  int sinif(MeraGunu m) => m.firtina ? 2 : (m.sert ? 1 : 0);
  final s = [...l]..sort((a, b) {
      final c = sinif(a).compareTo(sinif(b));
      if (c != 0) return c;
      final p = b.puan.compareTo(a.puan);
      return p != 0 ? p : a.r.effectiveWind.compareTo(b.r.effectiveWind);
    });
  final out = <MeraGunu>[];
  final yaka = <Side, int>{};
  for (final m in s) {
    if ((yaka[m.spot.side] ?? 0) >= 2) continue;
    out.add(m);
    yaka[m.spot.side] = (yaka[m.spot.side] ?? 0) + 1;
    if (out.length == 3) break;
  }
  return out;
}
