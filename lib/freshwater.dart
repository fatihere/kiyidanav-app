import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/services.dart' show rootBundle;

/// Tatlı su meraları: Türkiye göl ve barajları (uygulama içine gömülü veri: assets/data/tatli_su.json)

/// Bir avlanma yöntemi
class FwMethod {
  final String title;
  final String text;
  const FwMethod(this.title, this.text);
}

/// Önerilen ekipman: [query] kiyidanav.com ürün aramasında kullanılır
class FwGear {
  final String name;
  final String query;
  const FwGear(this.name, this.query);
}

/// Balık rehberi (yöntem + ekipman)
class FwFish {
  final String key;
  final String name;
  final String season;
  final String bait;
  final List<FwMethod> methods;
  final List<FwGear> gear;
  const FwFish({
    required this.key,
    required this.name,
    this.season = '',
    this.bait = '',
    this.methods = const [],
    this.gear = const [],
  });

  factory FwFish.fromJson(String key, Map<String, dynamic> j) => FwFish(
        key: key,
        name: '${j['ad'] ?? key}',
        season: '${j['sezon'] ?? ''}',
        bait: '${j['yem'] ?? ''}',
        methods: ((j['yontem'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => FwMethod('${m['baslik'] ?? ''}', '${m['aciklama'] ?? ''}'))
            .toList(),
        gear: ((j['ekipman'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => FwGear('${m['ad'] ?? ''}', '${m['ara'] ?? ''}'))
            .where((g) => g.name.isNotEmpty && g.query.isNotEmpty)
            .toList(),
      );
}

/// Bir göl / baraj
class FwPlace {
  final String id;
  final String name;
  final String type; // Doğal göl, Baraj gölü, Lagün…
  final String province;
  final String district;
  final double lat;
  final double lon;
  final String area;
  final String depth;
  final String surroundings; // Ormanlık, Kısmen ormanlık, Açık arazi…
  final String surroundingsNote;
  final String road;
  final String camp;
  final List<String> fish;
  final String tip;
  final String warning;
  final bool noFishing; // avlanmanın tamamen yasak olduğu yer (içme suyu vb.)

  const FwPlace({
    required this.id,
    required this.name,
    required this.type,
    required this.province,
    required this.district,
    required this.lat,
    required this.lon,
    this.area = '',
    this.depth = '',
    this.surroundings = '',
    this.surroundingsNote = '',
    this.road = '',
    this.camp = '',
    this.fish = const [],
    this.tip = '',
    this.warning = '',
    this.noFishing = false,
  });

  bool get isDam => type.toLowerCase().contains('baraj');


  factory FwPlace.fromJson(Map<String, dynamic> j) => FwPlace(
        id: '${j['id'] ?? ''}',
        name: '${j['ad'] ?? ''}',
        type: '${j['tur'] ?? ''}',
        province: '${j['il'] ?? ''}',
        district: '${j['ilce'] ?? ''}',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lon: (j['lon'] as num?)?.toDouble() ?? 0,
        area: '${j['alan'] ?? ''}',
        depth: '${j['derinlik'] ?? ''}',
        surroundings: '${j['cevre'] ?? ''}',
        surroundingsNote: '${j['cevreNot'] ?? ''}',
        road: '${j['ulasim'] ?? ''}',
        camp: '${j['kamp'] ?? ''}',
        fish: ((j['baliklar'] as List?) ?? const []).map((e) => '$e').toList(),
        tip: '${j['not'] ?? ''}',
        warning: '${j['uyari'] ?? ''}',
        noFishing: j['yasak'] == true,
      );

  /// Arama için: ad, il, ilçe, tür ve balık adları
  String searchText(Map<String, FwFish> guide) =>
      trLower([name, province, district, type, for (final f in fish) guide[f]?.name ?? f].join(' '));
}

class FwData {
  final List<FwPlace> places;
  final Map<String, FwFish> fish;
  final String note;
  const FwData({required this.places, required this.fish, this.note = ''});

  factory FwData.fromJson(Map<String, dynamic> j) {
    final fish = <String, FwFish>{};
    final raw = j['baliklar'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) fish['$k'] = FwFish.fromJson('$k', Map<String, dynamic>.from(v));
      });
    }
    final places = ((j['yerler'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FwPlace.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.name.isNotEmpty && FwProjection.inside(p.lon, p.lat))
        .toList()
      ..sort((a, b) {
        final c = trCompare(a.province, b.province);
        return c != 0 ? c : trCompare(a.name, b.name);
      });
    return FwData(places: places, fish: fish, note: '${j['not'] ?? ''}');
  }

  /// Bir merada çıkan balıkların ekipmanları (tekrarsız)
  List<FwGear> gearFor(FwPlace p) {
    final seen = <String>{};
    final out = <FwGear>[];
    for (final k in p.fish) {
      for (final g in fish[k]?.gear ?? const <FwGear>[]) {
        if (seen.add(g.query)) out.add(g);
      }
    }
    return out;
  }
}

/// Harita: il sınırları ve büyük göller (düz [boylam, enlem, boylam, enlem, …] dizileri)
class FwMapShapes {
  final List<MapEntry<String, List<List<double>>>> provinces;
  final List<List<double>> water;
  final String source;
  const FwMapShapes({this.provinces = const [], this.water = const [], this.source = ''});

  static List<double> _ring(dynamic r) =>
      r is List ? r.whereType<num>().map((e) => e.toDouble()).toList() : const <double>[];

  factory FwMapShapes.fromJson(Map<String, dynamic> j) => FwMapShapes(
        provinces: ((j['iller'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => MapEntry('${p['n'] ?? ''}',
                ((p['r'] as List?) ?? const []).map(_ring).where((r) => r.length >= 6).toList()))
            .toList(),
        water: ((j['su'] as List?) ?? const []).map(_ring).where((r) => r.length >= 6).toList(),
        source: '${j['kaynak'] ?? ''}',
      );
}

/// Türkiye için basit eşit-alanlı olmayan (equirectangular) izdüşüm
class FwProjection {
  static const minLon = 25.5, maxLon = 45.0, minLat = 35.7, maxLat = 42.3;

  /// Harita yüksekliği / genişliği (39° enlemde boylam daralması hesaba katılır)
  static final double aspect = (maxLat - minLat) / ((maxLon - minLon) * math.cos(39 * math.pi / 180));

  static bool inside(double lon, double lat) => lon > minLon && lon < maxLon && lat > minLat && lat < maxLat;

  static Offset project(double lon, double lat, Size s) =>
      Offset((lon - minLon) / (maxLon - minLon) * s.width, (maxLat - lat) / (maxLat - minLat) * s.height);
}

class FreshwaterService {
  static FwData? _data;
  static FwMapShapes? _map;

  static Future<FwData> load() async {
    if (_data != null) return _data!;
    final s = await rootBundle.loadString('assets/data/tatli_su.json');
    return _data = FwData.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
  }

  static Future<FwMapShapes> loadMap() async {
    if (_map != null) return _map!;
    try {
      final s = await rootBundle.loadString('assets/data/tr_harita.json');
      return _map = FwMapShapes.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return const FwMapShapes();
    }
  }
}

// ---------------- Türkçe yardımcılar ----------------

/// Türkçe küçük harf (İ→i, I→ı)
String trLower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Türkçe büyük harf (i→İ, ı→I)
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

const _trAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Türkçe alfabe sırasıyla karşılaştırma
int trCompare(String a, String b) {
  final x = trLower(a), y = trLower(b);
  final n = math.min(x.length, y.length);
  for (var i = 0; i < n; i++) {
    if (x[i] == y[i]) continue;
    final ix = _trAlphabet.indexOf(x[i]), iy = _trAlphabet.indexOf(y[i]);
    if (ix >= 0 && iy >= 0) return ix.compareTo(iy);
    return x[i].compareTo(y[i]);
  }
  return x.length.compareTo(y.length);
}
