import 'dart:convert';

import 'package:http/http.dart' as http;

import 'locate.dart';
import 'sea.dart';

/// 1.17.1: kıyıdaki yer adını bulur (Open-Meteo yer adları + OpenStreetMap / Nominatim).
/// Open-Meteo köy ve ilçeleri bilir ama plaj, koy, tabiat parkı gibi adları çoğu zaman bilmez
/// (ör. Kandıra'daki Uzunkum yalnız OpenStreetMap'te var); iki kaynak birlikte sorulur.
/// Yalnız kıyıya yakın (bir meraya 30 km'den yakın) sonuçlar alınır; aynı adlı birden çok yer varsa
/// [yakin] verilen meraya en yakın olan başa gelir (Kartal'daki biri için Germencik'teki Uzunkum değil, Kandıra'daki).
class YerArama {
  static const _ua = {'User-Agent': 'KiyidanAv/1.17 (+https://www.kiyidanav.com)', 'Accept-Language': 'tr'};

  static Future<List<Spot>> ara(String q, {Spot? yakin, bool onlyPublic = false, int adet = 6}) async {
    q = q.trim();
    if (q.length < 3) return const [];
    final adaylar = <(String, double, double)>[];
    await Future.wait([
      () async {
        try {
          final r = await http
              .get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': q, 'count': '10', 'language': 'tr', 'countryCode': 'TR'}))
              .timeout(const Duration(seconds: 6));
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          for (final x in (j is Map && j['results'] is List ? j['results'] as List : const [])) {
            if (x is! Map) continue;
            final la = (x['latitude'] as num?)?.toDouble(), lo = (x['longitude'] as num?)?.toDouble();
            if (la == null || lo == null) continue;
            final adi = '${x['name'] ?? q}';
            final ilce = '${x['admin2'] ?? ''}'.replaceAll(' İlçesi', '');
            adaylar.add((ilce.isNotEmpty && ilce != adi ? '$adi, $ilce' : adi, la, lo));
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final r = await http
              .get(Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'jsonv2', 'limit': '8', 'countrycodes': 'tr', 'addressdetails': '1'}),
                  headers: _ua)
              .timeout(const Duration(seconds: 7));
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          for (final x in (j is List ? j : const [])) {
            if (x is! Map) continue;
            final la = double.tryParse('${x['lat']}'), lo = double.tryParse('${x['lon']}');
            if (la == null || lo == null) continue;
            final a = x['address'] is Map ? x['address'] as Map : const {};
            final adi = '${x['name'] ?? ''}'.trim().isNotEmpty ? '${x['name']}' : q;
            final ilce = '${a['town'] ?? a['county'] ?? a['city'] ?? ''}';
            adaylar.add((ilce.isNotEmpty && !adi.contains(ilce) ? '$adi, $ilce' : adi, la, lo));
          }
        } catch (_) {}
      }(),
    ]);
    final out = <Spot>[];
    for (final (ad, la, lo) in adaylar) {
      final (n, km) = Locate.nearest(la, lo, onlyPublic: onlyPublic);
      if (km > 30) continue; // iç kesim
      if (out.any((s) => Locate.km(s.lat, s.lon, la, lo) < 1.0)) continue; // aynı yer iki kaynaktan
      out.add(Spot.pin(la, lo, n, ad: ad));
    }
    if (yakin != null) out.sort((a, b) => Locate.km(a.lat, a.lon, yakin.lat, yakin.lon).compareTo(Locate.km(b.lat, b.lon, yakin.lat, yakin.lon)));
    return out.take(adet).toList();
  }
}
