import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'main.dart';
import 'models.dart';
import 'notices.dart';
import 'screens/category_screen.dart';

/// Mağaza ekran görüntüleri için otomatik gezinti.
/// Yalnızca `--dart-define=EKRAN_TURU=true` ile derlenen simülatör sürümünde çalışır
/// (GitHub Actions → "Mağaza ekran görüntüleri"); mağazaya giden sürümde kapalıdır.
const ekranTuru = bool.fromEnvironment('EKRAN_TURU');

class EkranTuru {
  /// İlk görüntü açılıştan 25 sn sonra, sonra her 15 sn'de bir adım (iş akışı aynı zamanlamayla çeker)
  static const ilkBekleme = Duration(seconds: 25);
  static const adimArasi = Duration(seconds: 15);

  static Future<void> baslat() async {
    await appState.setMember(true); // üye içeriği görünsün (gerçek üyelik işlemi yapılmaz)
    final adimlar = <void Function()>[
      () => shellTab.value = Shell.tabHome,
      () => shellTab.value = Shell.tabReport,
      () => shellTab.value = Shell.tabFishkrok,
      () {
        shellTab.value = Shell.tabHome;
        navKey.currentState?.push(MaterialPageRoute(
            builder: (_) => const CategoryScreen(category: Category(id: 453, name: 'Olta Makinaları'))));
      },
      () {
        navKey.currentState?.popUntil((r) => r.isFirst);
        navKey.currentState?.push(MaterialPageRoute(
            builder: (_) => const CategoryScreen(category: Category(id: 236, name: 'LRF Ekipmanları'))));
      },
      () {
        navKey.currentState?.popUntil((r) => r.isFirst);
        shellTab.value = Shell.tabAccount;
      },
    ];
    // Görüntü alınmadan önce her ekranın verisi yüklensin diye adımlar bir önceki çekimden hemen sonra uygulanır
    adimlar.first();
    await Future<void>.delayed(ilkBekleme - const Duration(seconds: 12));
    for (final a in adimlar.skip(1)) {
      await Future<void>.delayed(adimArasi);
      a();
    }
  }
}
