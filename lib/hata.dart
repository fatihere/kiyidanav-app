import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Görünmeyen hataları görünür kılar: bir ekran açılamazsa boş/gri kalmak yerine
/// nedeni kısa bir mesajla gösterilir (kullanıcı ekran görüntüsüyle bildirebilir).
class Hata {
  static final mesajAnahtari = GlobalKey<ScaffoldMessengerState>();
  static DateTime _son = DateTime(2000);

  static bool _onemsiz(String s, String? kutuphane) =>
      kutuphane == 'image resource service' ||
      s.contains('RenderFlex overflowed') ||
      s.contains('NetworkImage') ||
      s.contains('HTTP request failed');

  static void kur() {
    final onceki = FlutterError.onError;
    FlutterError.onError = (d) {
      onceki?.call(d);
      final s = d.exceptionAsString();
      if (!_onemsiz(s, d.library)) goster(s);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      debugPrint('Yakalanmamış hata: $e\n$st');
      if (!_onemsiz('$e', null)) goster('$e');
      return true;
    };
    ErrorWidget.builder = (d) => Material(
          color: const Color(0xFFFFF4EC),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Tide.turuncu, size: 40),
                const SizedBox(height: 10),
                const Text('Bu bölüm açılamadı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_kisa(d.exceptionAsString()), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 6),
                const Text('Ekran görüntüsünü bize gönderirsen hemen düzeltiriz.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF6B6A60))),
              ]),
            ),
          ),
        );
  }

  static String _kisa(String s) => s.length > 220 ? '${s.substring(0, 220)}…' : s;

  /// Kısa bilgi mesajı (aynı anda yağmur gibi mesaj çıkmasın diye 3 sn'de bir)
  static void goster(String mesaj) {
    final now = DateTime.now();
    if (now.difference(_son).inSeconds < 3) return;
    _son = now;
    mesajAnahtari.currentState?.showSnackBar(SnackBar(
      content: Text('Bir sorun oluştu: ${_kisa(mesaj)}'),
      duration: const Duration(seconds: 6),
    ));
  }

  /// İşlemi çalıştırır; hata olursa mesaj gösterir (düğme "hiçbir şey yapmadı" gibi kalmasın)
  static Future<void> calistir(Future<void> Function() is_) async {
    try {
      await is_();
    } catch (e) {
      goster('$e');
    }
  }
}
