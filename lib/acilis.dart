import 'dart:io' show Platform;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'updates.dart';

/// 1.17.2: Panelde doğru "aktif cihaz" sayımı.
/// Uygulama ilk açılışta rastgele, kişiye bağlı olmayan bir kurulum kimliği üretir ve
/// ön planda açıldığı her gün en fazla bir kez sunucuya bildirir (Android / iPhone ayrı).
/// Sunucu kimliği günlük ve aylık tuzla özetleyip saklar; kimliğin kendisi tutulmaz.
class Acilis {
  static const _kimlikAnahtari = 'kav_kurulum_kimligi';
  static const _sonGunAnahtari = 'kav_acilis_son_gun';
  static bool _gonderiliyor = false;

  static String platform() {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'diger';
  }

  static String yeniKimlik([Random? r]) {
    final g = r ?? Random.secure();
    return List.generate(16, (_) => g.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String gun(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Uygulama açıldığında / öne geldiğinde çağrılır; aynı gün ikinci kez göndermez.
  static Future<void> bildir({http.Client? istemci, DateTime? simdi}) async {
    if (_gonderiliyor) return;
    _gonderiliyor = true;
    try {
      final p = await SharedPreferences.getInstance();
      final bugun = gun(simdi ?? DateTime.now());
      if (p.getString(_sonGunAnahtari) == bugun) return;
      var k = p.getString(_kimlikAnahtari) ?? '';
      if (k.length != 32) {
        k = yeniKimlik();
        await p.setString(_kimlikAnahtari, k);
      }
      final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {
        'a': 'acildi',
        'k': k,
        'p': platform(),
        'v': AppUpdate.name,
      });
      final c = istemci ?? http.Client();
      try {
        final r = await c.get(uri).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) await p.setString(_sonGunAnahtari, bugun);
      } finally {
        if (istemci == null) c.close();
      }
    } catch (_) {
      // sayım uygulamayı asla engellemez
    } finally {
      _gonderiliyor = false;
    }
  }
}
