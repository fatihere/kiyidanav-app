import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class Spot {
  final String name;
  final double lat;
  final double lon;
  const Spot(this.name, this.lat, this.lon);
}

const spots = [
  Spot('Kartal sahili', 40.885, 29.185),
  Spot('Rumelifeneri', 41.235, 29.110),
  Spot('Şile', 41.180, 29.610),
  Spot('Silivri', 41.070, 28.250),
  Spot('Tuzla', 40.815, 29.300),
  Spot('Karaköy', 41.021, 28.975),
];

class SeaReport {
  final double? windKmh;
  final double? gustKmh;
  final int? windDir;
  final double? waveM;
  final double? airC;
  final double? seaC;

  const SeaReport(
      {this.windKmh,
      this.gustKmh,
      this.windDir,
      this.waveM,
      this.airC,
      this.seaC});

  /// Kıyıdan atış için basit değerlendirme
  String get verdict {
    final w = windKmh ?? 0;
    final h = waveM ?? 0;
    if (w < 15 && h < 0.5) return 'Kıyıdan atış için ideal';
    if (w < 25 && h < 1.0) return 'Uygun, biraz ağır takım tercih et';
    if (w < 35 && h < 1.8) return 'Sert — korunaklı bir kıyı seç';
    return 'Fırtınalı — bugün kıyıdan uzak dur';
  }

  bool get isGood => (windKmh ?? 0) < 25 && (waveM ?? 0) < 1.0;

  String get windFrom {
    final d = windDir;
    if (d == null) return '';
    // Marmara'da kullanılan geleneksel rüzgâr adları
    const names = [
      'Yıldız', 'Poyraz', 'Gündoğusu', 'Keşişleme',
      'Kıble', 'Lodos', 'Günbatısı', 'Karayel'
    ];
    return names[((d % 360) / 45).round() % 8];
  }
}

class SeaService {
  static Future<SeaReport> fetch(Spot s) async {
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    final wx = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${s.lat}',
      'longitude': '${s.lon}',
      'current': 'temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'wind_speed_unit': 'kmh',
      'timezone': 'Europe/Istanbul',
    });
    final mr = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
      'latitude': '${s.lat}',
      'longitude': '${s.lon}',
      'current': 'wave_height,sea_surface_temperature',
    });
    final results = await Future.wait([
      http.get(wx).timeout(const Duration(seconds: 10)),
      http.get(mr).timeout(const Duration(seconds: 10)).catchError(
          (_) => http.Response('{}', 200)), // dalga verisi opsiyonel
    ]);
    final w = (jsonDecode(results[0].body)['current'] ?? {}) as Map;
    Map m = {};
    try {
      m = (jsonDecode(results[1].body)['current'] ?? {}) as Map;
    } catch (_) {}
    return SeaReport(
      windKmh: n(w['wind_speed_10m']),
      gustKmh: n(w['wind_gusts_10m']),
      windDir: n(w['wind_direction_10m'])?.round(),
      airC: n(w['temperature_2m']),
      waveM: n(m['wave_height']),
      seaC: n(m['sea_surface_temperature']),
    );
  }
}
