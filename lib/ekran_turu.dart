import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'main.dart';
import 'models.dart';
import 'notices.dart';
import 'screens/category_screen.dart';
import 'screens/freshwater_screen.dart';

/// Mağaza ekran görüntüleri için otomatik gezinti.
/// Yalnızca `--dart-define=EKRAN_TURU=true` ile derlenen simülatör sürümünde çalışır
/// (GitHub Actions → "Mağaza ekran görüntüleri"); mağazaya giden sürümde kapalıdır.
const ekranTuru = bool.fromEnvironment('EKRAN_TURU');

/// İş akışıyla el sıkışma (uygulamanın tmp klasörü üzerinden):
///  uygulama ekranı hazırlayıp `hazir_N` dosyasını yazar → iş akışı ekran görüntüsünü alıp `cekildi_N` yazar → sonraki ekran.
class EkranTuru {
  static const yukleme = Duration(seconds: 12);

  static Future<void> _bekle(int n) async {
    final kok = Directory.systemTemp.path;
    try {
      File('$kok/hazir_$n').writeAsStringSync('$n');
    } catch (_) {}
    final cekildi = File('$kok/cekildi_$n');
    for (var i = 0; i < 120; i++) {
      if (cekildi.existsSync()) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  static void _kok() => navKey.currentState?.popUntil((r) => r.isFirst);

  static void _ac(Widget w) => navKey.currentState?.push(MaterialPageRoute(builder: (_) => w));

  static Future<void> baslat() async {
    await appState.setMember(true); // üye içeriği görünsün (gerçek üyelik işlemi yapılmaz)
    final adimlar = <void Function()>[
      () => shellTab.value = Shell.tabHome,
      () => shellTab.value = Shell.tabReport,
      () => shellTab.value = Shell.tabFishkrok,
      () {
        shellTab.value = Shell.tabHome;
        _ac(const FreshwaterScreen());
      },
      () {
        _kok();
        _ac(const CategoryScreen(category: Category(id: 453, name: 'Olta Makinaları')));
      },
      () {
        _kok();
        _ac(const CategoryScreen(category: Category(id: 236, name: 'LRF Ekipmanları')));
      },
      () {
        _kok();
        shellTab.value = Shell.tabAccount;
      },
    ];
    for (var n = 0; n < adimlar.length; n++) {
      adimlar[n]();
      await Future<void>.delayed(n == 0 ? yukleme * 2 : yukleme);
      await _bekle(n + 1);
    }
    try {
      File('${Directory.systemTemp.path}/bitti').writeAsStringSync('${adimlar.length}');
    } catch (_) {}
  }
}
