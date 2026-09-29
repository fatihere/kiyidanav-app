import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum Side { anadolu, avrupa }

class Spot {
  final String name;
  final double lat;
  final double lon;
  final Side side;
  /// Boğaz içi: dalga modelleri Boğaz'ı çözümlemez, dalga yerine rüzgâr/akıntı esas alınır
  final bool strait;
  const Spot(this.name, this.lat, this.lon, this.side, {this.strait = false});
}

/// Anadolu yakası: Riva'dan Darıca'ya (kırmızı hat)
/// Avrupa yakası: Rumelifeneri'nden Semizkum'a (sarı hat)
const spots = [
  Spot('Riva', 41.225, 29.225, Side.anadolu),
  Spot('Beykoz', 41.132, 29.100, Side.anadolu, strait: true),
  Spot('Üsküdar', 41.025, 29.012, Side.anadolu),
  Spot('Moda', 40.980, 29.025, Side.anadolu),
  Spot('Maltepe', 40.920, 29.130, Side.anadolu),
  Spot('Kartal', 40.885, 29.185, Side.anadolu),
  Spot('Pendik', 40.870, 29.235, Side.anadolu),
  Spot('Tuzla', 40.815, 29.300, Side.anadolu),
  Spot('Darıca', 40.760, 29.380, Side.anadolu),
  Spot('Rumelifeneri', 41.235, 29.110, Side.avrupa),
  Spot('Garipçe', 41.214, 29.108, Side.avrupa),
  Spot('Sarıyer', 41.168, 29.057, Side.avrupa, strait: true),
  Spot('Bebek', 41.077, 29.044, Side.avrupa, strait: true),
  Spot('Karaköy', 41.021, 28.975, Side.avrupa),
  Spot('Yenikapı', 41.002, 28.950, Side.avrupa),
  Spot('Bakırköy', 40.975, 28.870, Side.avrupa),
  Spot('Florya', 40.968, 28.795, Side.avrupa),
  Spot('Avcılar', 40.975, 28.715, Side.avrupa),
  Spot('Büyükçekmece', 41.010, 28.585, Side.avrupa),
  Spot('Semizkum', 41.043, 28.470, Side.avrupa),
];

List<Spot> spotsOf(Side s) => spots.where((e) => e.side == s).toList();

class SeaReport {
  final double? windKmh;
  final double? gustKmh;
  final int? windDir;
  final double? waveM;
  /// Önümüzdeki 6 saatteki en yüksek dalga
  final double? waveMax6h;
  final double? airC;
  final double? seaC;
  final double? pressure;
  /// Şu anki yağış (mm) ve günün toplam yağışı (mm)
  final double? rainNow;
  final double? rainDay;
  final bool strait;

  const SeaReport(
      {this.windKmh,
      this.gustKmh,
      this.windDir,
      this.waveM,
      this.waveMax6h,
      this.airC,
      this.seaC,
      this.pressure,
      this.rainNow,
      this.rainDay,
      this.strait = false});

  /// Hamleleri de hesaba katan etkin rüzgâr (kıyıda atışı asıl zorlayan hamlelerdir)
  double get effectiveWind {
    final w = windKmh ?? 0;
    final g = (gustKmh ?? 0) * 0.7;
    return w > g ? w : g;
  }

  /// Şimdiki ve önümüzdeki 6 saatin en yüksek dalgası (Boğaz içinde dalga verisi kullanılmaz)
  double get effectiveWave {
    if (strait) return 0;
    final a = waveM ?? 0;
    final b = waveMax6h ?? 0;
    return a > b ? a : b;
  }

  bool get rainy => (rainNow ?? 0) >= 0.5 || (rainDay ?? 0) >= 8;

  String get verdict {
    final w = effectiveWind;
    final h = effectiveWave;
    String v;
    if (w >= 40 || h >= 1.8) {
      v = 'Fırtınalı — bugün kıyıdan uzak dur';
    } else if (w >= 28 || h >= 1.0) {
      v = 'Sert — korunaklı bir kıyı seç';
    } else if (w >= 18 || h >= 0.5) {
      v = 'Uygun, biraz ağır takım tercih et';
    } else {
      v = 'Kıyıdan atış için ideal';
    }
    return rainy ? '$v · yağışlı' : v;
  }

  bool get isGood => effectiveWind < 28 && effectiveWave < 1.0 && !rainy;

  String get windFrom {
    final d = windDir;
    if (d == null) return '';
    const names = ['Yıldız', 'Poyraz', 'Gündoğusu', 'Keşişleme', 'Kıble', 'Lodos', 'Günbatısı', 'Karayel'];
    return names[((d % 360) / 45).round() % 8];
  }
}

/// Bir günün özeti (av raporu için)
class DayForecast {
  final DateTime date;
  final double? windMax;
  final double? gustMax;
  final double? rainSum;
  final double? waveMax;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? tempMax;
  final double? tempMin;
  const DayForecast(
      {required this.date,
      this.windMax,
      this.gustMax,
      this.rainSum,
      this.waveMax,
      this.sunrise,
      this.sunset,
      this.tempMax,
      this.tempMin});

  /// Günün etkin rüzgârı (hamle dahil)
  double? get effectiveWind {
    final w = windMax;
    final g = gustMax;
    if (w == null && g == null) return null;
    final a = w ?? 0;
    final b = (g ?? 0) * 0.7;
    return a > b ? a : b;
  }
}

class SpotForecast {
  final Spot spot;
  final SeaReport now;
  final List<DayForecast> days;
  final double? pressureTrend; // önümüzdeki 6 saat (hPa)
  const SpotForecast({required this.spot, required this.now, this.days = const [], this.pressureTrend});
}

class SeaService {
  static double? _n(dynamic v) => v is num ? v.toDouble() : null;

  static dynamic _at(dynamic list, int i) =>
      (list is List && i < list.length) ? list[i] : null;

  /// Saatlik seride şimdiki saatten itibaren [hours] saatin en büyük değeri
  static double? maxNextHours(Map hourly, String key, int hours, {DateTime? now}) {
    final times = (hourly['time'] as List?) ?? const [];
    final vals = (hourly[key] as List?) ?? const [];
    final t0 = now ?? DateTime.now();
    final start = DateTime(t0.year, t0.month, t0.day, t0.hour);
    double? best;
    for (var i = 0; i < times.length && i < vals.length; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null || t.isBefore(start) || !t.isBefore(start.add(Duration(hours: hours)))) continue;
      final v = _n(vals[i]);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  /// Bir yakadaki tüm noktaları tek istekte getirir (şimdiki durum).
  static Future<List<SpotForecast>> fetchSide(Side side) async {
    final list = spotsOf(side);
    final lat = list.map((e) => e.lat).join(',');
    final lon = list.map((e) => e.lon).join(',');
    final wx = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat,
      'longitude': lon,
      'current': 'temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,precipitation',
      'daily': 'precipitation_sum',
      'forecast_days': '1',
      'wind_speed_unit': 'kmh',
      'timezone': 'Europe/Istanbul',
    });
    final mr = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
      'latitude': lat,
      'longitude': lon,
      'current': 'wave_height,sea_surface_temperature',
      'hourly': 'wave_height',
      'forecast_days': '2',
      'timezone': 'Europe/Istanbul',
    });
    final res = await Future.wait([
      http.get(wx).timeout(const Duration(seconds: 12)),
      http.get(mr).timeout(const Duration(seconds: 12)).catchError((_) => http.Response('[]', 200)),
    ]);
    dynamic w = jsonDecode(res[0].body);
    dynamic m;
    try {
      m = jsonDecode(res[1].body);
    } catch (_) {
      m = [];
    }
    // Tek nokta olursa API liste yerine nesne döner
    if (w is Map) w = [w];
    if (m is Map) m = [m];
    final out = <SpotForecast>[];
    for (var i = 0; i < list.length; i++) {
      final wi = (_at(w, i) as Map?) ?? const {};
      final mi = (_at(m, i) as Map?) ?? const {};
      final wc = (wi['current'] ?? {}) as Map;
      final mc = (mi['current'] ?? {}) as Map;
      final daily = (wi['daily'] ?? {}) as Map;
      out.add(SpotForecast(
        spot: list[i],
        now: SeaReport(
          windKmh: _n(wc['wind_speed_10m']),
          gustKmh: _n(wc['wind_gusts_10m']),
          windDir: _n(wc['wind_direction_10m'])?.round(),
          airC: _n(wc['temperature_2m']),
          pressure: _n(wc['surface_pressure']),
          rainNow: _n(wc['precipitation']),
          rainDay: _n(_at(daily['precipitation_sum'], 0)),
          waveM: list[i].strait ? null : _n(mc['wave_height']),
          waveMax6h: list[i].strait ? null : maxNextHours((mi['hourly'] ?? {}) as Map, 'wave_height', 6),
          seaC: _n(mc['sea_surface_temperature']),
          strait: list[i].strait,
        ),
      ));
    }
    return out;
  }

  /// Tek nokta için 7 günlük tahmin + basınç eğilimi (av raporu)
  static Future<SpotForecast> fetchWeek(Spot s) async {
    final wx = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${s.lat}',
      'longitude': '${s.lon}',
      'current': 'temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,precipitation',
      'hourly': 'surface_pressure',
      'daily': 'wind_speed_10m_max,wind_gusts_10m_max,precipitation_sum,sunrise,sunset,temperature_2m_max,temperature_2m_min',
      'forecast_days': '7',
      'wind_speed_unit': 'kmh',
      'timezone': 'Europe/Istanbul',
    });
    final mr = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
      'latitude': '${s.lat}',
      'longitude': '${s.lon}',
      'current': 'wave_height,sea_surface_temperature',
      'hourly': 'wave_height',
      'daily': 'wave_height_max',
      'forecast_days': '7',
      'timezone': 'Europe/Istanbul',
    });
    final res = await Future.wait([
      http.get(wx).timeout(const Duration(seconds: 12)),
      http.get(mr).timeout(const Duration(seconds: 12)).catchError((_) => http.Response('{}', 200)),
    ]);
    final w = jsonDecode(res[0].body) as Map<String, dynamic>;
    Map<String, dynamic> m = {};
    try {
      m = jsonDecode(res[1].body) as Map<String, dynamic>;
    } catch (_) {}
    final wc = (w['current'] ?? {}) as Map;
    final mc = (m['current'] ?? {}) as Map;
    final d = (w['daily'] ?? {}) as Map;
    final md = (m['daily'] ?? {}) as Map;

    // Basınç eğilimi: şimdiki saat ile 6 saat sonrası
    double? trend;
    final hourly = (w['hourly'] ?? {}) as Map;
    final times = (hourly['time'] as List?) ?? const [];
    final press = (hourly['surface_pressure'] as List?) ?? const [];
    final nowKey = DateTime.now();
    for (var i = 0; i < times.length && i + 6 < press.length; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t != null && !t.isBefore(DateTime(nowKey.year, nowKey.month, nowKey.day, nowKey.hour))) {
        final a = _n(press[i]);
        final b = _n(press[i + 6]);
        if (a != null && b != null) trend = b - a;
        break;
      }
    }

    final days = <DayForecast>[];
    final dt = (d['time'] as List?) ?? const [];
    for (var i = 0; i < dt.length; i++) {
      final date = DateTime.tryParse('${dt[i]}');
      if (date == null) continue;
      days.add(DayForecast(
        date: date,
        windMax: _n(_at(d['wind_speed_10m_max'], i)),
        gustMax: _n(_at(d['wind_gusts_10m_max'], i)),
        rainSum: _n(_at(d['precipitation_sum'], i)),
        waveMax: s.strait ? null : _n(_at(md['wave_height_max'], i)),
        sunrise: DateTime.tryParse('${_at(d['sunrise'], i)}'),
        sunset: DateTime.tryParse('${_at(d['sunset'], i)}'),
        tempMax: _n(_at(d['temperature_2m_max'], i)),
        tempMin: _n(_at(d['temperature_2m_min'], i)),
      ));
    }
    return SpotForecast(
      spot: s,
      now: SeaReport(
        windKmh: _n(wc['wind_speed_10m']),
        gustKmh: _n(wc['wind_gusts_10m']),
        windDir: _n(wc['wind_direction_10m'])?.round(),
        airC: _n(wc['temperature_2m']),
        pressure: _n(wc['surface_pressure']),
        rainNow: _n(wc['precipitation']),
        rainDay: days.isNotEmpty ? days.first.rainSum : null,
        waveM: s.strait ? null : _n(mc['wave_height']),
        waveMax6h: s.strait ? null : maxNextHours((m['hourly'] ?? {}) as Map, 'wave_height', 6),
        seaC: _n(mc['sea_surface_temperature']),
        strait: s.strait,
      ),
      days: days,
      pressureTrend: trend,
    );
  }
}
