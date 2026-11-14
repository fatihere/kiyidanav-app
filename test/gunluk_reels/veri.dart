// Günlük Reels — veri: uygulamanın rapor ekranıyla AYNI hesap (report_screen._load + FishingScore + bugunkuKiyilama)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

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
  /// 15.11.2026: meranın ili (OpenStreetMap il sınırlarından)
  final String il;
  MeraGunu(this.spot, this.f, this.puan, this.k, this.hukum, this.info, this.turler, {this.il = ''});

  SeaReport get r => f.now;
  bool get firtina => r.effectiveWind >= 40 || r.effectiveWave >= 1.8;
  bool get sert => r.effectiveWind >= 28 || r.effectiveWave >= 1.0;

  Map<String, Object?> json() => {
        'mera': spot.name,
        'il': il,
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

Future<MeraGunu?> meraGunu(Spot s, DateTime now, {String il = ''}) async {
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
    return MeraGunu(s, f, puan, k, hukum, inf, turler, il: il);
  } catch (e) {
    // ignore: avoid_print
    print('atlandı: ${s.name}: $e');
    return null;
  }
}

/// Günün 3 merası — her gün farklı: kıyıdan avlanılabilir (en iyi hava sınıfındaki) meralar arasından,
/// tarihe bağlı tohumla, puana göre ağırlıklı RASTGELE seçilir; her yakadan en çok 2. Aynı gün yeniden üretilirse
/// aynı meralar çıkar (tohum = tarih). Seçilenler puana göre sıralanır (1. mera = en yüksek puan).
List<MeraGunu> secim(List<MeraGunu> l, DateTime gun, {int adet = 3, int tohum = 0}) {
  if (l.length <= adet) return [...l]..sort((a, b) => b.puan.compareTo(a.puan));
  int sinif(MeraGunu m) => m.firtina ? 2 : (m.sert ? 1 : 0);
  final gunNo = gun.difference(DateTime(gun.year)).inDays;
  final rnd = math.Random(gun.year * 1000 + gunNo + tohum * 7919);
  // aday havuzu: en iyi hava sınıfı; 3'ten azsa bir sonraki sınıf da eklenir
  final siniflar = l.map(sinif).toSet().toList()..sort();
  final aday = <MeraGunu>[];
  for (final s in siniflar) {
    aday.addAll(l.where((m) => sinif(m) == s));
    if (aday.length >= adet * 2) break;
  }
  final enDusuk = aday.map((m) => m.puan).reduce(math.min);
  final out = <MeraGunu>[];
  final yaka = <Side, int>{};
  while (out.length < adet && aday.isNotEmpty) {
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


// ------------------------------------------------------------------ 15.11.2026: il bazlı günlük plan
/// Türkiye il sınırları (assets/data/tr_harita.json, © OpenStreetMap): her halka (boylam, enlem) noktaları
class IlHaritasi {
  final Map<String, List<List<Offset>>> iller;
  final Map<String, List<Rect>> _kutular;
  IlHaritasi(this.iller)
      : _kutular = {
          for (final e in iller.entries)
            e.key: [
              for (final r in e.value)
                Rect.fromLTRB(r.map((p) => p.dx).reduce(math.min), r.map((p) => p.dy).reduce(math.min),
                    r.map((p) => p.dx).reduce(math.max), r.map((p) => p.dy).reduce(math.max))
            ]
        };

  factory IlHaritasi.dosyadan([String yol = 'assets/data/tr_harita.json']) {
    final j = jsonDecode(File(yol).readAsStringSync()) as Map;
    final out = <String, List<List<Offset>>>{};
    for (final il in (j['iller'] as List)) {
      out[il['n'] as String] = [
        for (final r in (il['r'] as List))
          [for (var i = 0; i + 1 < (r as List).length; i += 2) Offset((r[i] as num).toDouble(), (r[i + 1] as num).toDouble())]
      ];
    }
    return IlHaritasi(out);
  }

  List<List<Offset>> get tumHalkalar => [for (final l in iller.values) ...l];

  static bool _icinde(List<Offset> r, double x, double y) {
    var ic = false;
    for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
      final a = r[i], b = r[j];
      if ((a.dy > y) != (b.dy > y) && x < (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy) + a.dx) ic = !ic;
    }
    return ic;
  }

  /// Kıyı iğnesi denizde ve iki ile eşit yakınsa doğru il (ilçe bilgisinden)
  static const _elle = {'Tuzla': 'İstanbul', 'Hersek': 'Yalova', 'Altınova': 'Yalova', 'Dereköy': 'Yalova'};

  /// (boylam, enlem) noktasının a–b kenarına uzaklığının karesi (boylam enleme göre ölçekli)
  static double _kenarUzakligi(Offset a, Offset b, double x, double y) {
    const k = 0.76; // cos(40°)
    final ax = a.dx * k, bx = b.dx * k, px = x * k;
    final dx = bx - ax, dy = b.dy - a.dy;
    final l2 = dx * dx + dy * dy;
    var t = l2 == 0 ? 0.0 : ((px - ax) * dx + (y - a.dy) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    final qx = ax + t * dx - px, qy = a.dy + t * dy - y;
    return qx * qx + qy * qy;
  }

  /// Meranın ili (önce elle düzeltme listesi)
  String meraIli(Spot s) => _elle[s.name] ?? ilBul(s.lat, s.lon);

  /// Noktanın ili; nokta denizdeyse (kıyı iğnesi) sınırı en yakın il
  String ilBul(double lat, double lon) {
    for (final e in iller.entries) {
      final k = _kutular[e.key]!;
      for (var i = 0; i < e.value.length; i++) {
        if (k[i].contains(Offset(lon, lat)) && _icinde(e.value[i], lon, lat)) return e.key;
      }
    }
    var enIyi = '', d = double.infinity;
    for (final e in iller.entries) {
      final k = _kutular[e.key]!;
      for (var i = 0; i < e.value.length; i++) {
        if (!k[i].inflate(0.4).contains(Offset(lon, lat))) continue;
        final r = e.value[i];
        for (var j = 0; j < r.length; j++) {
          final dd = _kenarUzakligi(r[j], r[(j + 1) % r.length], lon, lat);
          if (dd < d) {
            d = dd;
            enIyi = e.key;
          }
        }
      }
    }
    return enIyi;
  }
}

/// Belirli günler için elle plan: test/gunluk_reels/plan.json {"2026-11-16": [["İstanbul", 3], ["Kocaeli", 3]]}
/// Planı olmayan gün: meraları olan kıyı illerinden tarihe bağlı rastgele 3 farklı il, her ilden 1 mera.
List<(String, int)> gunPlani(DateTime gun, Iterable<String> kiyiIlleri, {Map<String, Object?>? plan}) {
  final anahtar = '${gun.year}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';
  final p = plan ?? _planDosyasi();
  final ozel = p[anahtar];
  if (ozel is List && ozel.isNotEmpty) {
    return [for (final x in ozel) ((x as List)[0] as String, ((x[1] as num?) ?? 3).toInt())];
  }
  final l = kiyiIlleri.toList()..sort();
  final rnd = math.Random(gun.year * 1000 + gun.difference(DateTime(gun.year)).inDays + 4242);
  l.shuffle(rnd);
  return [for (final il in l.take(3)) (il, 1)];
}

Map<String, Object?> _planDosyasi() {
  final f = File('test/gunluk_reels/plan.json');
  if (!f.existsSync()) return const {};
  try {
    return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
  } catch (_) {
    return const {};
  }
}

/// Video başlığındaki yer: tek il → İL, iki il → İL1 · İL2, daha çok → TÜRKİYE KIYILARI
String yerBasligi(List<MeraGunu> l) {
  final iller = <String>[];
  for (final m in l) {
    if (m.il.isNotEmpty && !iller.contains(m.il)) iller.add(m.il);
  }
  if (iller.isEmpty) return 'İSTANBUL';
  if (iller.length <= 2) return iller.map(buyukHarfTr).join(' · ');
  return 'TÜRKİYE KIYILARI';
}

String buyukHarfTr(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
String kucukHarfTr(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
