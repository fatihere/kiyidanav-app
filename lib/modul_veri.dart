import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'sea.dart';

/// Modüller için ek deniz verisi: dalga ve akıntı yönü, deniz seviyesi serisi.
/// Ana rapordan ayrı istenir; alınamazsa rapor etkilenmez.
class EkDeniz {
  final double? dalgaYon; // dalganın geldiği yön (°)
  final double? akintiYon; // akıntının gittiği yön (°)
  final double? akintiHiz; // km/s
  final List<DateTime> seviyeZaman;
  final List<double?> seviye; // m (deniz seviyesi, gelgit + kabarma)
  const EkDeniz({this.dalgaYon, this.akintiYon, this.akintiHiz, this.seviyeZaman = const [], this.seviye = const []});

  static final Map<String, (DateTime, EkDeniz)> _cache = {};

  static Future<EkDeniz?> of(Spot s) async {
    final c = _cache[s.name];
    if (c != null && DateTime.now().difference(c.$1).inMinutes < 30) return c.$2;
    try {
      final uri = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
        'latitude': '${s.lat}',
        'longitude': '${s.lon}',
        'current': 'wave_direction,ocean_current_direction,ocean_current_velocity',
        'hourly': 'sea_level_height_msl',
        'forecast_days': '2',
        'timezone': 'Europe/Istanbul',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      if (j is! Map) return null;
      final cur = (j['current'] ?? {}) as Map;
      final h = (j['hourly'] ?? {}) as Map;
      double? n(dynamic v) => v is num ? v.toDouble() : null;
      final zaman = <DateTime>[];
      final sev = <double?>[];
      final ts = (h['time'] as List?) ?? const [];
      final vs = (h['sea_level_height_msl'] as List?) ?? const [];
      for (var i = 0; i < ts.length; i++) {
        final t = DateTime.tryParse('${ts[i]}');
        if (t == null) continue;
        zaman.add(t);
        sev.add(i < vs.length ? n(vs[i]) : null);
      }
      final e = EkDeniz(
        dalgaYon: s.strait ? null : n(cur['wave_direction']),
        akintiYon: n(cur['ocean_current_direction']),
        akintiHiz: n(cur['ocean_current_velocity']),
        seviyeZaman: zaman,
        seviye: sev,
      );
      _cache[s.name] = (DateTime.now(), e);
      return e;
    } catch (_) {
      return null;
    }
  }
}

/// "Bu merada balık genelde kaç metrede?" — onaylı üye bildirimlerinden
class AvIstat {
  final String balik;
  final int n;
  final String mesafe;
  final String derinlik;
  final String saat;
  const AvIstat(this.balik, this.n, this.mesafe, this.derinlik, this.saat);

  static Future<List<AvIstat>> of(String mera) async {
    try {
      final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'avistat', 'mera': mera});
      final r = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map || j['ok'] != true) return const [];
      return ((j['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AvIstat('${e['balik'] ?? ''}', e['n'] is num ? (e['n'] as num).toInt() : 0, '${e['mesafe'] ?? ''}',
              '${e['derinlik'] ?? ''}', '${e['saat'] ?? ''}'))
          .where((e) => e.balik.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
