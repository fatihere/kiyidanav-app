import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'olcum_yorum.dart';

/// Yönetim panelindeki "Modüller" ekranından gelen ayarlar (mobil-api.php config → moduller).
///
/// Sunucu yalnız "yayında" ve "test" durumundaki modülleri gönderir. Test modülleri yalnız
/// panelde test üyesi olarak eklenen hesaplarda görünür (üye numarasının tek yönlü özeti karşılaştırılır).
class ModulCfg {
  final String id;
  final bool test;
  final bool app;
  final bool web;
  final bool uye;
  final int sira;
  final String baslik;
  final String alt;
  final String renk; // '#rrggbb' ya da boş (temadan)
  final String sablon; // derin, acik, cam, serit ya da boş (temadan)
  final Map<String, dynamic> ayar;

  const ModulCfg({
    required this.id,
    this.test = false,
    this.app = true,
    this.web = true,
    this.uye = true,
    this.sira = 0,
    this.baslik = '',
    this.alt = '',
    this.renk = '',
    this.sablon = '',
    this.ayar = const {},
  });

  factory ModulCfg.fromJson(String id, Map<String, dynamic> j) => ModulCfg(
        id: id,
        test: j['test'] == true,
        app: j['app'] != false,
        web: j['web'] != false,
        uye: j['uye'] != false,
        sira: j['sira'] is num ? (j['sira'] as num).toInt() : 0,
        baslik: '${j['baslik'] ?? ''}',
        alt: '${j['alt'] ?? ''}',
        renk: '${j['renk'] ?? ''}',
        sablon: '${j['sablon'] ?? ''}',
        ayar: j['ayar'] is Map ? Map<String, dynamic>.from(j['ayar'] as Map) : const {},
      );

  bool b(String k, [bool d = false]) {
    final v = ayar[k];
    return v is bool ? v : d;
  }

  double n(String k, double d) {
    final v = ayar[k];
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll(',', '.')) ?? d;
  }

  String s(String k, [String d = '']) {
    final v = ayar[k];
    return v == null || '$v'.isEmpty ? d : '$v';
  }

  /// Panelde tablo olarak girilen liste (satır = alan → değer)
  List<Map<String, dynamic>> l(String k) {
    final v = ayar[k];
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

/// Ortak tasarım (panel → Tasarım ve şablon)
class ModulTema {
  final int ana;
  final int ana2;
  final int vurgu;
  final int iyi;
  final int orta;
  final int zayif;
  final String font;
  final double kose;
  final bool kompakt;
  final String sablon;

  const ModulTema({
    this.ana = 0xFF0E3B43,
    this.ana2 = 0xFF2A6F76,
    this.vurgu = 0xFFF46C22,
    this.iyi = 0xFF2E8B57,
    this.orta = 0xFFC98A1B,
    this.zayif = 0xFFB0413E,
    this.font = 'Armata',
    this.kose = 18,
    this.kompakt = false,
    this.sablon = 'derin',
  });

  static int? renk(dynamic v) {
    final s = '$v';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return 0xFF000000 | int.parse(s.substring(1), radix: 16);
  }

  factory ModulTema.fromJson(Map<String, dynamic> j) {
    const d = ModulTema();
    return ModulTema(
      ana: renk(j['ana']) ?? d.ana,
      ana2: renk(j['ana2']) ?? d.ana2,
      vurgu: renk(j['vurgu']) ?? d.vurgu,
      iyi: renk(j['iyi']) ?? d.iyi,
      orta: renk(j['orta']) ?? d.orta,
      zayif: renk(j['zayif']) ?? d.zayif,
      font: (j['font'] == 'Armata' || j['font'] == null) ? 'Armata' : '',
      kose: j['kose'] is num ? (j['kose'] as num).toDouble().clamp(0, 28).toDouble() : d.kose,
      kompakt: j['yogunluk'] == 'kompakt',
      sablon: const ['derin', 'acik', 'cam', 'serit'].contains(j['sablon']) ? j['sablon'] as String : d.sablon,
    );
  }
}

class Moduller {
  static Map<String, ModulCfg> _m = {};
  static ModulTema tema = const ModulTema();
  static Set<String> _test = {};

  /// Bu cihazdaki üyenin numarası (av anahtarından); bilinmiyorsa 0
  static int uyeNo = 0;

  /// Sunucu ayarı hiç gelmediyse (eski sunucu) "mevcut" modüller açık kabul edilir
  static bool _yuklendi = false;

  static void yukle(Map<String, dynamic> j) {
    final m = <String, ModulCfg>{};
    final raw = j['moduller'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) m['$k'] = ModulCfg.fromJson('$k', Map<String, dynamic>.from(v));
      });
    }
    _m = m;
    _yuklendi = raw is Map;
    tema = j['modul_tema'] is Map ? ModulTema.fromJson(Map<String, dynamic>.from(j['modul_tema'] as Map)) : const ModulTema();
    _test = ((j['test_uyeler'] as List?) ?? const []).map((e) => '$e').toSet();
    // Ölçüm açıklamaları: panelde düzenlenen basınç kuralları
    final oy = _m['olcum_yorum'];
    Yorum.panelden(oy?.l('basinc') ?? const [], oy?.s('notMetni') ?? '');
  }

  /// Panel ve sunucuyla aynı: sha256("kiyidanav-test|<üye no>") ilk 12 karakter
  static String testOzet(int id) => sha256.convert(utf8.encode('kiyidanav-test|$id')).toString().substring(0, 12);

  static bool get testUyesi => uyeNo > 0 && _test.contains(testOzet(uyeNo));

  /// Av anahtarının gövdesinden üye numarası ({"c": 123, ...})
  static int anahtardanUye(String? token) {
    if (token == null || !token.contains('.')) return 0;
    try {
      final body = token.split('.').first;
      final d = jsonDecode(utf8.decode(base64Url.decode(body.padRight((body.length + 3) ~/ 4 * 4, '='))));
      return d is Map && d['c'] is num ? (d['c'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Uygulamada gösterilecek modül (kapalıysa, testteyse ve test üyesi değilse, ya da yalnız webdeyse null).
  /// [uye]: kullanıcı giriş yapmış mı (üyelere özel modüller için)
  static ModulCfg? app(String id, {required bool uye}) {
    final c = _m[id];
    if (c == null) {
      if (!_yuklendi && (id == 'olcum_yorum' || id == 'web_mera')) return ModulCfg(id: id);
      return null;
    }
    if (!c.app) return null;
    if (c.test && !testUyesi) return null;
    if (c.uye && !uye) return null;
    return c;
  }

  /// Modül panelde tanımlı ve açık mı (görünürlük kuralı olmadan)
  static bool tanimli(String id) => _m.containsKey(id) || (!_yuklendi && (id == 'olcum_yorum' || id == 'web_mera'));

  static List<ModulCfg> sirali(Iterable<String> ids, {required bool uye}) {
    final out = <ModulCfg>[];
    for (final id in ids) {
      final c = app(id, uye: uye);
      if (c != null) out.add(c);
    }
    out.sort((a, b) => a.sira.compareTo(b.sira));
    return out;
  }
}
