import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'theme.dart';
import 'updates.dart';

/// Hata yönetimi.
///
/// 1.12.1'de arka plandaki tüm hatalar ekrana "Bir sorun oluştu: …" diye yazılıyordu.
/// Telefonun eklentilerinden (bildirim, ses, satın alma, ana ekran kartı…) gelen ve
/// uygulamanın çalışmasını etkilemeyen PlatformException'lar da kullanıcıya
/// "java.lang…" metniyle görünüyordu. 1.12.2'den itibaren:
///  - Arka plan hataları ekranda GÖSTERİLMEZ; cihazda kayda alınır ve sunucuya bildirilir.
///  - Kullanıcının bastığı bir düğmenin işlemi başarısız olursa sade bir Türkçe mesaj çıkar.
///  - Bir ekran gerçekten çizilemezse o bölümde anlaşılır bir uyarı kartı görünür.
class Hata {
  static final mesajAnahtari = GlobalKey<ScaffoldMessengerState>();
  static DateTime _son = DateTime(2000);
  static const _kayitAnahtari = 'hata_kayit_v1';
  static final Set<String> _bildirilen = {};

  static void kur() {
    final onceki = FlutterError.onError;
    FlutterError.onError = (d) {
      onceki?.call(d);
      kaydet(d.exception, d.stack, kaynak: d.library ?? 'flutter');
    };
    PlatformDispatcher.instance.onError = (e, st) {
      debugPrint('Yakalanmamış hata: $e\n$st');
      kaydet(e, st, kaynak: 'async');
      return true; // uygulama kapanmasın
    };
    ErrorWidget.builder = (d) {
      kaydet(d.exception, d.stack, kaynak: 'ekran');
      return const Material(
        color: Color(0xFFFFF4EC),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: Tide.turuncu, size: 40),
              SizedBox(height: 10),
              Text('Bu bölüm şu an açılamadı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Geri dönüp tekrar dene. Sorun bize otomatik bildirildi.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF6B6A60))),
            ]),
          ),
        ),
      );
    };
  }

  /// Teknik metni kullanıcıya göstermeyiz; anlaşılır bir cümleye çeviririz.
  static String sadelestir(Object e) {
    if (e is PlatformException || e is MissingPluginException) {
      return 'Telefonun bu işlemi şu an tamamlayamadı. Biraz sonra tekrar dene.';
    }
    final s = '$e';
    if (s.contains('java.') || s.contains('Exception') || s.contains('Error') || s.length > 160) {
      return 'İşlem tamamlanamadı. Biraz sonra tekrar dene.';
    }
    return s; // ApiException gibi zaten Türkçe olan mesajlar
  }

  /// Kullanıcının başlattığı bir işlem başarısız olduğunda kısa ve sade mesaj (3 sn'de en fazla bir)
  static void goster(Object hata) {
    kaydet(hata, StackTrace.current, kaynak: 'islem');
    final now = DateTime.now();
    if (now.difference(_son).inSeconds < 3) return;
    _son = now;
    mesajAnahtari.currentState?.showSnackBar(SnackBar(
      content: Text(sadelestir(hata)),
      duration: const Duration(seconds: 4),
    ));
  }

  /// İşlemi çalıştırır; hata olursa sade mesaj gösterir (düğme "hiçbir şey yapmadı" gibi kalmasın)
  static Future<void> calistir(Future<void> Function() is_) async {
    try {
      await is_();
    } catch (e) {
      goster(e);
    }
  }

  static bool _onemsiz(String s) =>
      s.contains('RenderFlex overflowed') ||
      s.contains('NetworkImage') ||
      s.contains('HTTP request failed') ||
      s.contains('SocketException') ||
      s.contains('Connection closed') ||
      s.contains('ClientException');

  /// Hatayı cihazda saklar (son 30) ve aynı oturumda her farklı hatayı bir kez sunucuya bildirir.
  static void kaydet(Object e, StackTrace? st, {required String kaynak}) {
    final metin = '$e';
    if (_onemsiz(metin)) return;
    final yigin = (st?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(8).join('\n');
    final kayit = {
      't': DateTime.now().toIso8601String(),
      'k': kaynak,
      'v': '${AppUpdate.name}+${AppUpdate.build}',
      'h': metin.length > 600 ? metin.substring(0, 600) : metin,
      's': yigin.length > 900 ? yigin.substring(0, 900) : yigin,
    };
    unawaited(_sakla(kayit));
    final anahtar = metin.length > 120 ? metin.substring(0, 120) : metin;
    if (_bildirilen.length < 20 && _bildirilen.add(anahtar)) unawaited(_bildir(kayit));
  }

  static Future<void> _sakla(Map<String, String> kayit) async {
    try {
      final p = await SharedPreferences.getInstance();
      final liste = p.getStringList(_kayitAnahtari) ?? <String>[];
      liste.add(jsonEncode(kayit));
      while (liste.length > 30) {
        liste.removeAt(0);
      }
      await p.setStringList(_kayitAnahtari, liste);
    } catch (_) {}
  }

  static Future<void> _bildir(Map<String, String> kayit) async {
    try {
      final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'hata'});
      if (uri.scheme != 'https') return;
      await http
          .post(uri,
              headers: const {'Content-Type': 'application/json', 'User-Agent': 'KiyidanAv-Android/1.0'},
              body: jsonEncode({...kayit, 'p': defaultTargetPlatform.name}))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // bildirim gitmese de olur; kayıt cihazda duruyor
    }
  }

  /// Cihazdaki son hata kayıtları (destek ekranı / tanılama için)
  static Future<List<Map<String, dynamic>>> kayitlar() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_kayitAnahtari) ?? const <String>[])
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
