import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'moduller.dart';

/// Çevrimdışı mod (panel → Modüller → Çevrimdışı mod): başarılı yanıtlar telefonda saklanır; internet yokken
/// son kayıt gösterilir (en fazla panelde yazılan saat kadar eski). Kayalıkta çekmeyen yerde son rapor açılır.
class Cevrimdisi {
  static http.Client istemci = http.Client();

  /// Son gösterilen kaydın zamanı (null: canlı veri)
  static final ValueNotifier<DateTime?> kullanilan = ValueNotifier<DateTime?>(null);

  static const _dizin = 'cd_dizin_v1';
  static const _enCok = 40;

  static ModulCfg? get _modul => Moduller.app('cevrimdisi', uye: true);

  /// Modül açıksa saklanır/kullanılır; [herZaman]: ayar dosyası gibi modülden bağımsız saklananlar
  static bool _acik(bool herZaman) => herZaman || _modul != null;

  static Duration get gecerlilik => Duration(hours: (_modul?.n('saat', 12) ?? 12).round().clamp(1, 168).toInt());

  static String _anahtar(Uri u) => 'cd_${md5.convert(utf8.encode(u.toString())).toString()}';

  static Future<http.Response> get(Uri uri,
      {Map<String, String>? headers,
      Duration timeout = const Duration(seconds: 12),
      bool herZaman = false,
      bool sakla = true}) async {
    if (!sakla) return istemci.get(uri, headers: headers).timeout(timeout);
    try {
      final r = await istemci.get(uri, headers: headers).timeout(timeout);
      if (r.statusCode == 200 && _acik(herZaman)) {
        unawaited(_yaz(uri, r.bodyBytes));
        kullanilan.value = null;
      }
      return r;
    } catch (e) {
      if (_acik(herZaman)) {
        final k = await oku(uri, herZaman: herZaman);
        if (k != null) {
          if (!herZaman) kullanilan.value = k.$2;
          return http.Response.bytes(k.$1, 200, headers: const {'content-type': 'application/json; charset=utf-8'});
        }
      }
      rethrow;
    }
  }

  static Future<void> _yaz(Uri uri, List<int> govde) async {
    if (govde.length > 400000) return;
    try {
      final p = await SharedPreferences.getInstance();
      final k = _anahtar(uri);
      await p.setString(k, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'b': base64.encode(govde)}));
      final dizin = (p.getStringList(_dizin) ?? <String>[])..remove(k);
      dizin.insert(0, k);
      while (dizin.length > _enCok) {
        await p.remove(dizin.removeLast());
      }
      await p.setStringList(_dizin, dizin);
    } catch (_) {}
  }

  /// Saklı yanıt ve zamanı (geçerlilik süresi dolduysa null)
  static Future<(List<int>, DateTime)?> oku(Uri uri, {bool herZaman = false}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_anahtar(uri));
      if (s == null) return null;
      final j = jsonDecode(s) as Map<String, dynamic>;
      final t = DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt());
      if (!herZaman && DateTime.now().difference(t) > gecerlilik) return null;
      return (base64.decode('${j['b']}'), t);
    } catch (_) {
      return null;
    }
  }
}
