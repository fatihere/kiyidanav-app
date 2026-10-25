import 'package:flutter/services.dart';

/// Yerel ekran koruması.
///  - Android: pencereye FLAG_SECURE (ekran görüntüsü ve kayıt siyah çıkar)
///  - iPhone: güvenli katman (ekran görüntüsü boş çıkar) + ekran kaydı/yansıtma başlayınca [kayitDegisti] çağrılır
class EkranKorumaKanal {
  static const _k = MethodChannel('kiyidanav/ekran_koruma');
  static void Function(bool kayit)? _dinleyici;

  static Future<void> koru(bool acik, {void Function(bool kayit)? kayitDegisti}) async {
    _dinleyici = acik ? kayitDegisti : null;
    _k.setMethodCallHandler(acik
        ? (c) async {
            if (c.method == 'kayit') _dinleyici?.call(c.arguments == true);
            return null;
          }
        : null);
    await _k.invokeMethod<bool>('koru', acik);
  }

  static Future<bool> kayitVar() async => (await _k.invokeMethod<bool>('kayitVar')) ?? false;
}
