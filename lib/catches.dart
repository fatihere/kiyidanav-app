import 'dart:async';
import 'dart:convert';
import 'dart:io' show PathNotFoundException, SocketException;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cevrimdisi.dart';
import 'config.dart';
import 'moduller.dart';

/// Üyelerin gönderdiği, yönetici onaylı av bildirimi
class CatchReport {
  final String id;
  final String spot;
  final String fish;
  final int count;
  final double kg;
  final String bait;
  final String note;
  final String name; // "Fatih Y."
  final String spotInfo; // gönderenin yazdığı mera bilgisi (dip, derinlik, akıntı…)
  final String instagram; // kullanıcı adı, @ olmadan
  final String igLink; // KıyıdanAv Instagram paylaşımı (varsa)
  final DateTime? time;
  final List<String> photos;

  const CatchReport({
    required this.id,
    required this.spot,
    required this.fish,
    this.count = 0,
    this.kg = 0,
    this.bait = '',
    this.note = '',
    this.name = '',
    this.spotInfo = '',
    this.instagram = '',
    this.igLink = '',
    this.time,
    this.photos = const [],
  });

  factory CatchReport.fromJson(Map<String, dynamic> j) => CatchReport(
        id: '${j['id'] ?? ''}',
        spot: '${j['mera'] ?? ''}',
        fish: '${j['balik'] ?? ''}',
        count: j['adet'] is num ? (j['adet'] as num).toInt() : int.tryParse('${j['adet']}') ?? 0,
        kg: j['kg'] is num ? (j['kg'] as num).toDouble() : double.tryParse('${j['kg']}') ?? 0,
        bait: '${j['yem'] ?? ''}',
        note: '${j['not'] ?? ''}',
        name: '${j['ad'] ?? ''}',
        spotInfo: '${j['mera_bilgi'] ?? ''}',
        instagram: CatchService.normalizeInstagram('${j['instagram'] ?? ''}') ?? '',
        igLink: '${j['ig_link'] ?? ''}'.startsWith('https://www.instagram.com/') ? '${j['ig_link']}' : '',
        time: DateTime.tryParse('${j['saat'] ?? ''}'),
        photos: ((j['fotolar'] as List?) ?? const [])
            .map((e) => '$e')
            .where((u) => u.startsWith('https://'))
            .take(3)
            .toList(),
      );

  /// "3 adet · 1,2 kg"
  String get amount {
    final p = <String>[];
    if (count > 0) p.add('$count adet');
    if (kg > 0) p.add('${kg.toStringAsFixed(kg < 10 ? 1 : 0).replaceAll('.', ',')} kg');
    return p.join(' · ');
  }

  /// "5 saat önce"
  String ago([DateTime? now]) {
    final t = time;
    if (t == null) return '';
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} saat önce';
    return '${d.inDays} gün önce';
  }
}

class CatchService {
  static List<CatchReport>? _all;
  static DateTime? _at;

  /// Son 48 saatin onaylı avları (1 dakika önbellek)
  static Future<List<CatchReport>> recent({bool force = false}) async {
    if (!force && _all != null && _at != null && DateTime.now().difference(_at!).inSeconds < 60) return _all!;
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'avlar'});
    final r = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map || j['ok'] != true) return _all ?? const [];
    _all = ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CatchReport.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty && c.fish.isNotEmpty)
        .toList();
    _at = DateTime.now();
    return _all!;
  }

  /// 1.13.1: Keşfet'teki "Balıkçılarımızın son avları": süre sınırı olmadan en yeni 20 onaylı av (bölüm hiç kaybolmaz)
  static List<CatchReport>? _son;
  static DateTime? _sonAt;
  static Future<List<CatchReport>> latest() async {
    if (_son != null && _sonAt != null && DateTime.now().difference(_sonAt!).inSeconds < 60) return _son!;
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'avlar', 'son': '1'});
    final r = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map || j['ok'] != true) return _son ?? const [];
    _son = ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CatchReport.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty && c.fish.isNotEmpty)
        .toList();
    _sonAt = DateTime.now();
    if (_son!.isEmpty) {
      // Sunucu eski sürümse son 14 günü dene
      try {
        final r2 = await http
            .get(Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'avlar', 'saat': '336'}),
                headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 12));
        final j2 = jsonDecode(utf8.decode(r2.bodyBytes));
        if (j2 is Map && j2['ok'] == true) {
          _son = ((j2['items'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => CatchReport.fromJson(Map<String, dynamic>.from(e)))
              .where((c) => c.id.isNotEmpty && c.fish.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return _son!;
  }

  static Future<List<CatchReport>> forSpot(String spot) async {
    try {
      return (await recent()).where((c) => c.spot == spot).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- Üyelik anahtarı ----------------
  static const _tokenKey = 'av_anahtar_v1';
  static const sessionPath = 'mobil-av.php?oturum=1';

  // ---------------- Instagram hesabı ----------------
  static const _igKey = 'ig_hesap_v1';

  /// "@ad", "ad" veya "instagram.com/ad" → "ad" (geçersizse null)
  static String? normalizeInstagram(String v) {
    var s = v.trim();
    final m = RegExp(r'instagram\.com/([A-Za-z0-9._]+)', caseSensitive: false).firstMatch(s);
    if (m != null) s = m.group(1)!;
    s = s.replaceFirst(RegExp(r'^@+'), '').replaceAll(RegExp(r'/+$'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{1,30}$').hasMatch(s) || s.startsWith('.') || s.endsWith('.') || s.contains('..')) {
      return null;
    }
    return s;
  }

  static Future<String> savedInstagram() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_igKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> saveInstagram(String v) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_igKey, v);
    } catch (_) {}
  }

  static Future<String?> token() async {
    try {
      final t = (await SharedPreferences.getInstance()).getString(_tokenKey);
      if (t == null || !t.contains('.')) return null;
      // Süresi geçmiş mi? (gövde base64url JSON: {"e": son geçerlilik})
      final body = t.split('.').first;
      final pad = body.padRight((body.length + 3) ~/ 4 * 4, '=');
      final d = jsonDecode(utf8.decode(base64Url.decode(pad)));
      final exp = d is Map && d['e'] is num ? (d['e'] as num).toInt() : 0;
      if (exp * 1000 < DateTime.now().millisecondsSinceEpoch + 3600 * 1000) return null;
      Moduller.uyeNo = Moduller.anahtardanUye(t);
      return t;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String? t) async {
    Moduller.uyeNo = Moduller.anahtardanUye(t);
    try {
      final p = await SharedPreferences.getInstance();
      if (t == null || t.isEmpty) {
        await p.remove(_tokenKey);
      } else {
        await p.setString(_tokenKey, t);
      }
    } catch (_) {}
  }

  /// Av bildirimi gönderir. Hata mesajını döndürür (başarıda null).
  /// [needsLogin] sunucu üyeliği doğrulayamadıysa true olur.
  static Future<(String? error, bool needsLogin, String? message)> submit({
    required String token,
    required String spot,
    required String fish,
    int count = 0,
    double kg = 0,
    String bait = '',
    String note = '',
    String spotInfo = '',
    required String instagram,
    bool instagramConsent = false,
    DateTime? time,
    String timeRange = '',
    List<String> photoPaths = const [],
    String distance = '',
    String depth = '',
    Map<String, Object> weather = const {},
    int productId = 0,
    double length = 0,
    String tournament = '',
  }) async {
    final fields = <String, String>{
      'mera': spot,
      'balik': fish,
      'adet': '$count',
      'kg': kg.toStringAsFixed(2),
      'yem': bait,
      'not': note,
      'mera_bilgi': spotInfo,
      'instagram': instagram,
      'ig_izin': instagramConsent ? '1' : '0',
      'saat': (time ?? DateTime.now()).toIso8601String().substring(0, 16),
      if (timeRange.isNotEmpty) 'saat_aralik': timeRange,
      if (distance.isNotEmpty) 'mesafe': distance,
      if (depth.isNotEmpty) 'derinlik': depth,
      for (final e in weather.entries) 'hava_${e.key}': '${e.value}',
      if (productId > 0) 'urun_id': '$productId',
      if (length > 0) 'boy': length.toStringAsFixed(1),
      if (tournament.isNotEmpty) 'turnuva': tournament,
    };
    Future<http.Response> send(Uri uri) async {
      final req = http.MultipartRequest('POST', uri)
        ..followRedirects = false
        ..headers['X-Av-Anahtar'] = token
        ..headers['Accept'] = 'application/json'
        ..fields.addAll(fields);
      for (final p in photoPaths.take(3)) {
        req.files.add(await http.MultipartFile.fromPath('foto[]', p, filename: 'av.jpg'));
      }
      return http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    }

    http.Response res;
    try {
      res = await send(Uri.parse('${AppConfig.siteUrl}mobil-av.php'));
      // Sunucu başka adrese yönlendirirse (ör. www) aynı bildirimi oraya bir kez daha gönder
      final loc = res.headers['location'];
      if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
        final to = Uri.parse('${AppConfig.siteUrl}mobil-av.php').resolve(loc);
        if (to.scheme == 'https' && to.host.endsWith(AppConfig.siteHost)) res = await send(to);
      }
    } on TimeoutException {
      return ('Gönderim çok uzun sürdü. Bağlantın yavaş olabilir; daha az fotoğrafla tekrar dene.', false, null);
    } on SocketException {
      return ('İnternet bağlantısı yok. Bağlanınca tekrar dene.', false, null);
    } on http.ClientException {
      return ('Sunucuya ulaşılamadı. Biraz sonra tekrar dene.', false, null);
    } on PathNotFoundException {
      return ('Seçilen fotoğraf telefonda bulunamadı. Fotoğrafı kaldırıp yeniden ekle.', false, null);
    } catch (e) {
      return ('Gönderilemedi ($e). Tekrar dene.', false, null);
    }
    Object? j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return ('Sunucu beklenmeyen bir yanıt verdi (kod ${res.statusCode}). Biraz sonra tekrar dene.', false, null);
    }
    if (j is Map && j['ok'] == true) {
      _all = null; // listeyi tazele
      return (null, false, '${j['mesaj'] ?? 'Av bildirimin alındı.'}');
    }
    final login = j is Map && j['giris'] == true;
    if (login) await saveToken(null);
    return ('${j is Map ? j['error'] ?? 'Gönderilemedi.' : 'Gönderilemedi.'}', login, null);
  }
}

/// Uydu verisi: deniz suyu sıcaklığı eğilimi ve klorofil (yem balığı göstergesi)
class SatInfo {
  final double? sst;
  final double? sstChange5d; // °C, son 5 gün
  final double? chl; // mg/m³
  final int? chlChangePct; // son 3 gün ile önceki hafta karşılaştırması
  final String source;

  /// Su berraklığı: Kd490 (m⁻¹). Düşük = berrak, yüksek = bulanık
  final double? kd490;

  /// Termal cephe: mera çevresinde (~9 km) en sıcak ve en soğuk nokta farkı
  final double? termalFark;
  final double? termalSicak;
  final double? termalSoguk;
  final String termalSicakYon;
  final String termalSogukYon;
  const SatInfo(
      {this.sst,
      this.sstChange5d,
      this.chl,
      this.chlChangePct,
      this.source = '',
      this.kd490,
      this.termalFark,
      this.termalSicak,
      this.termalSoguk,
      this.termalSicakYon = '',
      this.termalSogukYon = ''});

  bool get isEmpty => sst == null && chl == null && kd490 == null && termalFark == null;

  factory SatInfo.fromJson(Map<String, dynamic> j) {
    final s = j['sst'] is Map ? j['sst'] as Map : const {};
    final k = j['klorofil'] is Map ? j['klorofil'] as Map : const {};
    double? d(dynamic v) => v is num ? v.toDouble() : null;
    return SatInfo(
      sst: d(s['deger']),
      sstChange5d: d(s['degisim5']),
      chl: d(k['deger']),
      chlChangePct: k['degisim_yuzde'] is num ? (k['degisim_yuzde'] as num).toInt() : null,
      source: '${j['kaynak'] ?? ''}',
      kd490: j['berraklik'] is Map ? d((j['berraklik'] as Map)['kd490']) : null,
      termalFark: j['termal'] is Map ? d((j['termal'] as Map)['fark']) : null,
      termalSicak: j['termal'] is Map ? d((j['termal'] as Map)['sicak']) : null,
      termalSoguk: j['termal'] is Map ? d((j['termal'] as Map)['soguk']) : null,
      termalSicakYon: j['termal'] is Map ? '${(j['termal'] as Map)['sicak_yon'] ?? ''}' : '',
      termalSogukYon: j['termal'] is Map ? '${(j['termal'] as Map)['soguk_yon'] ?? ''}' : '',
    );
  }

  /// "Su soğuyor" / "Yem balığı artıyor" gibi kısa yorum
  String comment(int month) {
    final parts = <String>[];
    final c = sstChange5d;
    if (c != null) {
      if (c <= -0.8) {
        parts.add(month >= 9 && month <= 12 ? 'Su soğuyor: palamut/lüfer göçü için olumlu' : 'Su soğuyor');
      } else if (c >= 0.8) {
        parts.add('Su ısınıyor');
      }
    }
    final p = chlChangePct;
    if (p != null && p >= 15) parts.add('Klorofil artıyor: yem balığı yoğunlaşabilir');
    if (p != null && p <= -20) parts.add('Klorofil azalıyor');
    return parts.join(' · ');
  }
}

class SatService {
  static final Map<String, SatInfo> _cache = {};

  static Future<SatInfo?> of(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {
        'a': 'uydu',
        'lat': lat.toStringAsFixed(2),
        'lon': lon.toStringAsFixed(2),
      });
      final r = await Cevrimdisi.get(uri, headers: const {'Accept': 'application/json'}, timeout: const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map || j['ok'] != true) return null;
      final s = SatInfo.fromJson(Map<String, dynamic>.from(j));
      if (s.isEmpty) return null;
      return _cache[key] = s;
    } catch (_) {
      return null;
    }
  }
}
