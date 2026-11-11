/// 1.17.0: saatlik av skoru, en iyi saat pencereleri ve türe göre skor.
///
/// Saatlik skor, günlük skorla (FishingScore.compute) aynı kurallardan çıkar; üzerine günün saati (şafak/akşam),
/// tahmini solunar dönemler (ayın meridyenden geçişi) ve av kayıtlarından öğrenilen düzeltmeler (SkorAyar) eklenir.
/// Tür skoru: bölgedeki yaygınlık × sezon × o saatin türün sevdiği koşullara uygunluğu.
/// Saf Dart (test edilebilir); ekran kartı saatlik_karti.dart'tadır.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'balik_rehberi.dart';
import 'config.dart';
import 'sea.dart';
import 'solunar.dart';

// =================================================================== av kayıtlarıyla öğrenilen düzeltmeler
/// Sunucudaki aylık betik (skor-ayar.php) onaylı av bildirimlerini o anın havasıyla karşılaştırır ve
/// kova başına küçük düzeltmeler üretir (±8 puan sınırında). Yeterli veri yokken boştur ve skor değişmez.
class SkorAyar {
  static Map<String, Map<String, int>> _d = const {};
  static int ornek = 0;
  static String tarih = '';
  static const _anahtar = 'skor_ayar_v1';

  static void yukleJson(Map j) {
    final out = <String, Map<String, int>>{};
    final a = j['ayar'];
    if (a is Map) {
      a.forEach((k, v) {
        if (v is Map) {
          out['$k'] = {for (final e in v.entries) '${e.key}': ((e.value as num?)?.round() ?? 0).clamp(-8, 8)};
        }
      });
    }
    _d = out;
    ornek = (j['n'] as num?)?.toInt() ?? 0;
    tarih = '${j['tarih'] ?? ''}';
  }

  /// Uygulama açılışında: önce son bilinen (cihazda), sonra sunucudaki güncel düzeltmeler
  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final eski = p.getString(_anahtar);
      if (eski != null) yukleJson(jsonDecode(eski) as Map);
      final r = await http.get(Uri.parse('${AppConfig.siteUrl}skor-ayar.json')).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map) {
          yukleJson(j);
          await p.setString(_anahtar, jsonEncode(j));
        }
      }
    } catch (_) {}
  }

  static int _k(String grup, String kova) => _d[grup]?[kova] ?? 0;

  static String ruzgarKova(double w) => w < 10 ? '0-10' : w < 20 ? '10-20' : w < 30 ? '20-30' : '30+';
  static String dalgaKova(double h) => h < 0.3 ? '0-0.3' : h < 0.8 ? '0.3-0.8' : h < 1.2 ? '0.8-1.2' : '1.2+';
  static String basincKova(double t) => t <= -1.5 ? 'dusuyor' : t >= 1.5 ? 'yukseliyor' : 'sabit';

  /// Hava koşullarına göre toplam düzeltme
  static int hava({double? windKmh, double? waveM, double? pressureTrend}) =>
      (windKmh == null ? 0 : _k('ruzgar', ruzgarKova(windKmh))) +
      (waveM == null ? 0 : _k('dalga', dalgaKova(waveM))) +
      (pressureTrend == null ? 0 : _k('basinc', basincKova(pressureTrend)));

  static int saat(String dilim) => _k('saat', dilim);

  /// Test için
  static void sifirla() {
    _d = const {};
    ornek = 0;
    tarih = '';
  }
}

// =================================================================== günün saati ve solunar
enum Dilim { safak, gunduz, aksam, gece }

extension DilimAd on Dilim {
  String get ad => const {Dilim.safak: 'Şafak', Dilim.gunduz: 'Gündüz', Dilim.aksam: 'Akşam', Dilim.gece: 'Gece'}[this]!;
  String get anahtar => name;
}

/// Saatin dilimi: gün doğumu/batımı ±1,5 saat şafak/akşam
Dilim dilimOf(DateTime t, DateTime? dogus, DateTime? batis) {
  final d = dogus ?? DateTime(t.year, t.month, t.day, 6, 30);
  final b = batis ?? DateTime(t.year, t.month, t.day, 18, 0);
  final dd = DateTime(t.year, t.month, t.day, d.hour, d.minute);
  final bb = DateTime(t.year, t.month, t.day, b.hour, b.minute);
  final orta = t.add(const Duration(minutes: 30)); // saatin ortası
  if (orta.difference(dd).inMinutes.abs() <= 90) return Dilim.safak;
  if (orta.difference(bb).inMinutes.abs() <= 90) return Dilim.aksam;
  if (orta.isAfter(dd) && orta.isBefore(bb)) return Dilim.gunduz;
  return Dilim.gece;
}

/// Tahmini solunar: ayın meridyenden geçişi (büyük dönem ±1 saat, karşı geçiş de büyük) ve
/// ayın doğuşu/batışı (geçişin ±6 saati; küçük dönem ±30 dk). Astronomik efemeris değil, yaklaşık hesap.
/// Dönen: 2 büyük, 1 küçük, 0 yok.
int solunarDonem(DateTime t, double lon) {
  // Yerel güneş öğlesi (TR, UTC+3): 12 + (45 − boylam) / 15 saat; ay her gün ~50 dk geç geçer
  final ogle = 12 + (45 - lon) / 15;
  final gecis = (ogle + Moon.age(t) / Moon.synodic * 24.8) % 24;
  final saat = t.hour + t.minute / 60 + 0.5;
  double fark(double a) {
    final x = (saat - a) % 24;
    final y = x < 0 ? x + 24 : x;
    return math.min(y, 24 - y);
  }

  if (fark(gecis) <= 1 || fark((gecis + 12.4) % 24) <= 1) return 2;
  if (fark((gecis + 6.2) % 24) <= 0.5 || fark((gecis - 6.2 + 24) % 24) <= 0.5) return 1;
  return 0;
}

// =================================================================== saatlik skor
class SaatSkoru {
  final HourForecast h;
  final int skor;
  final Dilim dilim;
  final int solunar;
  const SaatSkoru(this.h, this.skor, this.dilim, this.solunar);
  DateTime get time => h.time;
}

class SaatPencere {
  final DateTime bas, bit; // bit: son saatin sonu
  final int skor; // pencerenin ortalaması
  const SaatPencere(this.bas, this.bit, this.skor);
  String get metin => '${_hh(bas)}–${_hh(bit)}';
}

String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

class SaatlikSkor {
  /// Bir saatin skoru
  static SaatSkoru saat(HourForecast h, {DateTime? dogus, DateTime? batis, double lon = 29}) {
    final dilim = dilimOf(h.time, dogus, batis);
    final sol = solunarDonem(h.time, lon);
    var s = FishingScore.compute(h.time,
            windKmh: h.effectiveWind,
            waveM: h.waveM,
            pressureTrend: h.pressureTrend,
            // saatlik yağış günlük eşiklere göre ölçeklenir (1,5 mm/saat ≈ yağışlı gün)
            rainMm: h.rainMm == null ? null : h.rainMm! * 6,
            currentKmh: h.currentKmh)
        .toDouble();
    s += switch (dilim) {
      Dilim.safak => 12,
      Dilim.aksam => 12,
      Dilim.gunduz => (h.time.hour >= 11 && h.time.hour <= 15) ? -6 : 0,
      Dilim.gece => (h.time.hour >= 1 && h.time.hour <= 4) ? -8 : -2,
    };
    s += sol == 2 ? 6 : sol == 1 ? 3 : 0;
    s += SkorAyar.saat(dilim.anahtar);
    return SaatSkoru(h, s.round().clamp(10, 98), dilim, sol);
  }

  /// Tahminin tüm saatleri (gün doğumu/batımı o günün değeriyle)
  static List<SaatSkoru> hepsi(SpotForecast f) {
    final gunler = {for (final d in f.days) '${d.date.year}-${d.date.month}-${d.date.day}': d};
    return [
      for (final h in f.hours)
        saat(h,
            dogus: gunler['${h.time.year}-${h.time.month}-${h.time.day}']?.sunrise,
            batis: gunler['${h.time.year}-${h.time.month}-${h.time.day}']?.sunset,
            lon: f.spot.lon),
    ];
  }

  /// Bir günün saatleri (şimdiki saatten sonrası; gün 0 = bugün)
  static List<SaatSkoru> gun(List<SaatSkoru> l, int gun, {DateTime? simdi}) {
    final n = simdi ?? DateTime.now();
    final g = DateTime(n.year, n.month, n.day).add(Duration(days: gun));
    return l.where((x) => x.time.year == g.year && x.time.month == g.month && x.time.day == g.day).toList();
  }

  /// En iyi [adet] pencere (2 saatlik, çakışmayan; gece yarısı–04:00 arası önerilmez)
  static List<SaatPencere> enIyiPencereler(List<SaatSkoru> l, {int adet = 2, int uzunluk = 2}) {
    final adaylar = <SaatPencere>[];
    for (var i = 0; i + uzunluk <= l.length; i++) {
      final p = l.sublist(i, i + uzunluk);
      if (p.any((x) => x.time.hour >= 0 && x.time.hour < 4)) continue;
      // ardışık saatler olmalı
      if (p.last.time.difference(p.first.time).inHours != uzunluk - 1) continue;
      final ort = p.map((x) => x.skor).reduce((a, b) => a + b) / uzunluk;
      adaylar.add(SaatPencere(p.first.time, p.last.time.add(const Duration(hours: 1)), ort.round()));
    }
    adaylar.sort((a, b) => b.skor.compareTo(a.skor));
    final secilen = <SaatPencere>[];
    for (final a in adaylar) {
      if (secilen.any((s) => a.bas.isBefore(s.bit) && s.bas.isBefore(a.bit))) continue;
      secilen.add(a);
      if (secilen.length == adet) break;
    }
    secilen.sort((a, b) => a.bas.compareTo(b.bas));
    return secilen;
  }
}

// =================================================================== türe göre skor
/// Türün sevdiği koşullar (yaklaşık; kıyı balıkçılığı deneyimi ve tür rehberlerinden)
class TurTercih {
  final Map<Dilim, double> zaman; // 0–1
  final double dalgaMin, dalgaMax; // ideal dalga aralığı (m)
  final double ruzgarMax; // bunun üstü zorlar (km/s)
  final double suMin, suMax; // ideal su sıcaklığı (°C)
  const TurTercih(this.zaman, this.dalgaMin, this.dalgaMax, this.ruzgarMax, this.suMin, this.suMax);
}

const _sa = {Dilim.safak: 1.0, Dilim.aksam: 1.0, Dilim.gece: 0.6, Dilim.gunduz: 0.35}; // şafak–akşam avcısı
const _gc = {Dilim.gece: 1.0, Dilim.aksam: 0.8, Dilim.safak: 0.6, Dilim.gunduz: 0.2}; // gece balığı
const _gn = {Dilim.gunduz: 1.0, Dilim.safak: 0.8, Dilim.aksam: 0.8, Dilim.gece: 0.3}; // gündüz balığı
const _hp = {Dilim.gunduz: 0.8, Dilim.safak: 1.0, Dilim.aksam: 1.0, Dilim.gece: 0.7}; // her saat

const turTercihleri = <String, TurTercih>{
  'levrek': TurTercih(_sa, 0.3, 1.2, 35, 10, 20),
  'lufer': TurTercih(_sa, 0.2, 1.0, 30, 12, 20),
  'palamut': TurTercih(_sa, 0.1, 0.8, 30, 14, 22),
  'cupra': TurTercih(_gn, 0.0, 0.6, 25, 15, 26),
  'lidaki': TurTercih(_gn, 0.0, 0.5, 25, 16, 27),
  'sargoz': TurTercih(_sa, 0.3, 1.0, 30, 12, 24),
  'karagoz': TurTercih(_gc, 0.0, 0.6, 25, 12, 24),
  'mirmir': TurTercih(_gc, 0.1, 0.7, 25, 18, 28),
  'minekop': TurTercih(_gc, 0.2, 0.9, 25, 18, 26),
  'eskina': TurTercih(_gc, 0.0, 0.6, 25, 16, 26),
  'istavrit': TurTercih({Dilim.aksam: 1.0, Dilim.gece: 0.9, Dilim.safak: 0.8, Dilim.gunduz: 0.5}, 0.0, 0.6, 25, 8, 26),
  'kefal': TurTercih(_gn, 0.0, 0.5, 25, 8, 28),
  'mezgit': TurTercih(_hp, 0.0, 0.8, 30, 7, 15),
  'kalkan': TurTercih(_hp, 0.0, 0.7, 25, 7, 16),
  'barbunya': TurTercih(_gn, 0.0, 0.6, 25, 12, 22),
  'zargana': TurTercih(_gn, 0.0, 0.4, 20, 16, 26),
  'kolyoz': TurTercih({Dilim.gunduz: 0.9, Dilim.safak: 0.9, Dilim.aksam: 1.0, Dilim.gece: 0.3}, 0.0, 0.6, 25, 18, 26),
  'isparoz': TurTercih(_gn, 0.0, 0.5, 25, 16, 26),
  'izmarit': TurTercih(_gn, 0.0, 0.5, 25, 16, 26),
  'mercan': TurTercih({Dilim.aksam: 1.0, Dilim.gece: 0.8, Dilim.safak: 0.8, Dilim.gunduz: 0.5}, 0.0, 0.7, 25, 16, 26),
  'akya': TurTercih(_sa, 0.2, 1.0, 30, 18, 26),
  'sinarit': TurTercih({Dilim.safak: 1.0, Dilim.aksam: 0.8, Dilim.gunduz: 0.5, Dilim.gece: 0.4}, 0.0, 0.8, 25, 14, 22),
  'dil': TurTercih(_gc, 0.0, 0.6, 25, 12, 22),
  'sarikuyruk': TurTercih({Dilim.safak: 1.0, Dilim.aksam: 0.8, Dilim.gunduz: 0.6, Dilim.gece: 0.2}, 0.2, 1.0, 30, 20, 28),
  'iskorpit': TurTercih(_gc, 0.0, 0.6, 25, 10, 24),
  'kirlangic': TurTercih(_hp, 0.0, 0.7, 25, 10, 18),
};

class TurSkoru {
  final String tur; // anahtar (levrek…)
  final int skor; // en iyi saatteki yüzde
  final SaatPencere? pencere; // en iyi 2 saat
  const TurSkoru(this.tur, this.skor, this.pencere);
  String get ad => baliklar[tur]?.ad ?? tur;
}

/// Saatin türe uygunluğu (0–1)
double turUygunluk(TurTercih t, SaatSkoru s) {
  final h = s.h;
  double aralik(double? v, double a, double b, double tolerans) {
    if (v == null) return 0.7;
    if (v >= a && v <= b) return 1;
    final d = v < a ? a - v : v - b;
    return (1 - d / tolerans).clamp(0.0, 1.0);
  }

  final zaman = t.zaman[s.dilim] ?? 0.5;
  final dalga = h.waveM == null ? 0.75 : aralik(h.waveM, t.dalgaMin, t.dalgaMax, 0.8);
  final w = h.effectiveWind;
  final ruzgar = w == null ? 0.7 : (w <= t.ruzgarMax ? 1.0 : (1 - (w - t.ruzgarMax) / 20).clamp(0.0, 1.0));
  final su = aralik(h.seaC, t.suMin, t.suMax, 5);
  return 0.45 * zaman + 0.25 * dalga + 0.15 * ruzgar + 0.15 * su;
}

/// Bir günün (saat listesi) en olası türleri: her tür için en iyi saat penceresi ve yüzdesi
List<TurSkoru> turSkorlari(Spot spot, List<SaatSkoru> saatler, {int adet = 3, DateTime? zaman}) {
  if (saatler.isEmpty) return const [];
  final now = zaman ?? saatler.first.time;
  final bolge = balikBolgesi(spot);
  final out = <TurSkoru>[];
  for (final tur in bolgeTurleri(spot, now)) {
    final b = baliklar[tur];
    final t = turTercihleri[tur];
    if (b == null || t == null || b.yasakta(now)) continue;
    final ihtimal = avIhtimali(bolge, tur, now); // 0–3
    if (ihtimal <= 0.2) continue;
    final carpan = math.sqrt(ihtimal / 3); // yaygınlık × sezon
    final puan = [
      for (final s in saatler) (s, (s.skor * (0.35 + 0.65 * turUygunluk(t, s)) * carpan).round().clamp(5, 98)),
    ];
    // en iyi 2 saatlik pencere
    var enIyi = 0;
    SaatPencere? pencere;
    for (var i = 0; i < puan.length; i++) {
      final a = puan[i];
      if (a.$1.time.hour < 4) continue;
      final b2 = i + 1 < puan.length ? puan[i + 1] : null;
      final ort = b2 == null ? a.$2 : ((a.$2 + b2.$2) / 2).round();
      if (ort > enIyi) {
        enIyi = ort;
        pencere = SaatPencere(a.$1.time, (b2 ?? a).$1.time.add(const Duration(hours: 1)), ort);
      }
    }
    out.add(TurSkoru(tur, enIyi, pencere));
  }
  out.sort((a, b) => b.skor.compareTo(a.skor));
  return out.take(adet).toList();
}
