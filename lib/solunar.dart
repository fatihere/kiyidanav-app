import 'dart:math' as math;

/// Ay evresi ve av verimliliği tahmini.
/// Ay evresi astronomik olarak hesaplanır (ağ gerektirmez); verimlilik ise
/// ay evresi + rüzgâr + dalga + basınç eğiliminden türetilen bir tahmindir.
class Moon {
  static final _ref = DateTime.utc(2000, 1, 6, 18, 14); // bilinen yeni ay
  static const synodic = 29.530588853;

  /// Ayın yaşı (gün, 0 = yeni ay)
  static double age(DateTime t) {
    final days = t.toUtc().difference(_ref).inSeconds / 86400.0;
    final a = days % synodic;
    return a < 0 ? a + synodic : a;
  }

  /// Aydınlanma oranı 0..1
  static double illumination(DateTime t) =>
      (1 - math.cos(2 * math.pi * age(t) / synodic)) / 2;

  static bool waxing(DateTime t) => age(t) < synodic / 2;

  static String phaseName(DateTime t) {
    final a = age(t);
    if (a < 1.0) return 'Yeni Ay';
    if (a < 6.4) return 'Büyüyen Hilal';
    if (a < 8.4) return 'İlk Dördün';
    if (a < 13.8) return 'İlk Şişkin Ay';
    if (a < 15.8) return 'Dolunay';
    if (a < 21.1) return 'Son Şişkin Ay';
    if (a < 23.1) return 'Son Dördün';
    if (a < 28.5) return 'Son Hilal';
    return 'Yeni Ay';
  }

  /// Sadece aya göre temel verimlilik (%)
  static int baseScore(DateTime t) {
    switch (phaseName(t)) {
      case 'Yeni Ay':
      case 'Dolunay':
        return 90;
      case 'Büyüyen Hilal':
      case 'Son Hilal':
        return 75;
      case 'İlk Şişkin Ay':
      case 'Son Şişkin Ay':
        return 70;
      default:
        return 55; // dördünler
    }
  }
}

class FishingScore {
  /// Ay + hava koşullarına göre av verimliliği (%10 – %98)
  /// [pressureTrend]: önümüzdeki 6 saatteki basınç değişimi (hPa)
  static int compute(DateTime day,
      {double? windKmh, double? waveM, double? pressureTrend, double? rainMm}) {
    var s = Moon.baseScore(day).toDouble();
    final w = windKmh;
    if (w != null) {
      if (w < 10) {
        s += 5;
      } else if (w >= 30) {
        s -= 25;
      } else if (w >= 20) {
        s -= 10;
      }
    }
    final h = waveM;
    if (h != null) {
      if (h >= 2.0) {
        s -= 30;
      } else if (h >= 1.2) {
        s -= 15;
      } else if (h >= 0.3 && h < 0.8) {
        s += 5; // hafif dalga, levrek için iyi
      }
    }
    final p = pressureTrend;
    if (p != null) {
      if (p <= -1.5) s += 5; // cephe öncesi iştah
      if (p >= 2.5) s -= 5;
    }
    final r = rainMm;
    if (r != null) {
      if (r >= 20) {
        s -= 15;
      } else if (r >= 8) {
        s -= 8;
      }
    }
    return s.round().clamp(10, 98);
  }

  static String label(int score) {
    if (score >= 85) return 'Çok verimli';
    if (score >= 70) return 'Verimli';
    if (score >= 50) return 'Orta';
    if (score >= 30) return 'Zayıf';
    return 'Çok zayıf';
  }

  /// 1–5 balık simgesi
  static int fishCount(int score) => (score / 20).ceil().clamp(1, 5);
}
