import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ekran_koruma/ekran_koruma.dart';

import 'api.dart';
import 'ekran_turu.dart';
import 'theme.dart';
import 'yonetici.dart';

/// Ekran görüntüsü / ekran kaydı engeli (panel → Eklentiler → Ekran görüntüsü engeli)
///  - Android: FLAG_SECURE — ekran görüntüsü ve kayıt alınamaz (görüntü siyah çıkar)
///  - iPhone (1.13.1): uygulama güvenli katmanda çizilir — ekran görüntüsü boş çıkar; ekran kaydında içerik ayrıca gizlenir
class EkranKoruma {
  static final kayitVar = ValueNotifier<bool>(false);
  static bool _acik = false;

  /// Yönetici girişli telefonda (1.13.0) engel uygulanmaz: yönetici ekran görüntüsü alabilir
  static Future<void> uygula({bool zorla = false}) async {
    // Mağaza ekran görüntüsü derlemesinde (simülatör) koruma kapalı: görüntüler boş çıkmasın
    final ac = Api.config.features.ekranKoruma && !Yonetici.girisli && !ekranTuru;
    if (ac == _acik && !zorla) return;
    _acik = ac;
    try {
      if (Platform.isAndroid) {
        await EkranKorumaKanal.koru(ac);
      } else if (Platform.isIOS) {
        await EkranKorumaKanal.koru(ac, kayitDegisti: (kayit) => kayitVar.value = kayit);
        kayitVar.value = ac ? await EkranKorumaKanal.kayitVar() : false;
      }
    } catch (_) {
      // Koruma kurulamasa da uygulama çalışmaya devam eder
    }
  }
}

/// Ekran kaydı sürerken (iPhone) tüm içeriğin üstüne perde
class EkranKorumaKatmani extends StatelessWidget {
  final Widget child;
  const EkranKorumaKatmani({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EkranKoruma.kayitVar,
      builder: (context, kayit, _) => Stack(children: [
        child,
        if (kayit)
          const Positioned.fill(
            child: ColoredBox(
              color: Tide.derin,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Ekran kaydı sırasında KıyıdanAv içeriği gizlenir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
