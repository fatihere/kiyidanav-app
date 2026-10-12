import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notices.dart';
import 'overlays.dart';
import 'theme.dart';

/// Google Play'de yeni sürüm varsa açılışta "Güncelle" uyarısı gösterir ve güncellemeyi Play üzerinden yaptırır.
class AppUpdate {
  static const playUrl = 'https://play.google.com/store/apps/details?id=com.kiyidanav.kiyidanav';
  static const _askedKey = 'guncelleme_soruldu';

  /// Kurulu sürüm (sunucuya bildirilir; yeni sürüm bildirimini otomatik göndermek için)
  static String build = '';
  static String name = '';

  static Future<void> loadVersion() async {
    try {
      final i = await PackageInfo.fromPlatform();
      build = i.buildNumber;
      name = i.version;
    } catch (_) {}
  }

  /// Açılışta: güncelleme varsa (aynı sürüm için günde en fazla bir kez) sorar
  static Future<void> checkOnLaunch() async {
    if (!Platform.isAndroid) return;
    AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (e) {
      debugPrint('güncelleme kontrolü: $e'); // Play'den kurulmamış (ör. deneme APK'sı)
      return;
    }
    if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
      await _immediate();
      return;
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    final p = await SharedPreferences.getInstance();
    final key = '${info.availableVersionCode ?? 0}';
    final last = p.getString(_askedKey) ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (last == '$key|$today') return;
    await p.setString(_askedKey, '$key|$today');
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null || !ctx.mounted) return;
    final yes = await showDialog<bool>(
      context: ctx,
      builder: (c) => AppDialog(
        closeResult: false,
        icon: const Icon(Icons.system_update, color: Tide.turuncu, size: 38),
        title: 'Yeni sürüm hazır',
        content: const Text('KıyıdanAv\'ın yeni sürümü Google Play\'de. Yenilikleri ve düzeltmeleri almak için şimdi güncelle; '
            'birkaç saniye sürer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Sonra')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
            onPressed: () => Navigator.of(c).pop(true),
            icon: const Icon(Icons.download),
            label: const Text('Güncelle'),
          ),
        ],
      ),
    );
    if (yes == true) await _immediate();
  }

  /// Bildirimden veya bantdan "güncelle"
  static Future<void> start() async {
    if (Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable ||
            info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
          await _immediate();
          return;
        }
      } catch (_) {}
    }
    await launchUrl(Uri.parse(playUrl), mode: LaunchMode.externalApplication);
  }

  static Future<void> _immediate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('güncelleme başlatılamadı: $e');
      await launchUrl(Uri.parse(playUrl), mode: LaunchMode.externalApplication);
    }
  }
}
