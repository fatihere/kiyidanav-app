import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

import 'api.dart';
import 'theme.dart';

/// Ekran görüntüsü / ekran kaydı engeli (panel → Eklentiler → Ekran görüntüsü engeli)
///  - Android: FLAG_SECURE — ekran görüntüsü ve kayıt alınamaz (görüntü siyah çıkar)
///  - iPhone: Apple ekran görüntüsünü engellemeye izin vermez; ekran kaydı başladığında içerik gizlenir
class EkranKoruma {
  static final kayitVar = ValueNotifier<bool>(false);
  static bool _acik = false;

  static Future<void> uygula() async {
    final ac = Api.config.features.ekranKoruma;
    if (ac == _acik) return;
    _acik = ac;
    try {
      if (Platform.isAndroid) {
        ac ? await ScreenProtector.preventScreenshotOn() : await ScreenProtector.preventScreenshotOff();
      } else if (Platform.isIOS) {
        if (ac) {
          ScreenProtector.addListener(null, (kayit) => kayitVar.value = kayit);
          kayitVar.value = await ScreenProtector.isRecording();
        } else {
          ScreenProtector.removeListener();
          kayitVar.value = false;
        }
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
