import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ekran_koruma/ekran_koruma.dart';

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
