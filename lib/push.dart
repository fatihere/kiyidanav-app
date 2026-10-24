import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'catches.dart';
import 'notices.dart';
import 'topluluk_api.dart';

/// Tüm telefonların abone olduğu ortak kanal (panel bu kanala gönderir)
const pushTopic = 'hepsi';

/// Uygulama kapalıyken/arka plandayken gelen anlık bildirim.
/// Bildirimi Android kendisi gösterir; biz sadece "gösterildi" diye işaretleriz ki
/// 15 dakikalık yedek kontrol aynı bildirimi ikinci kez göstermesin.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage m) async {
  try {
    await Firebase.initializeApp();
    final id = m.data['id'];
    if (id is String && id.isNotEmpty) await Notices.markNotifiedIds([id]);
  } catch (e) {
    debugPrint('push arka plan: $e');
  }
}

class Push {
  static bool ready = false;

  static Future<void> start() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      if (Platform.isIOS) {
        // 1.13.0: iPhone bildirimleri (APNs). İzin + uygulama açıkken de bildirimi göster.
        await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
        // Konu aboneliği APNs kimliği gelmeden yapılamaz; birkaç saniye beklenir
        for (var i = 0; i < 10; i++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
      }
      await FirebaseMessaging.instance.subscribeToTopic(pushTopic);
      ready = true;
      // Mesaj bildirimleri bu telefona gelsin: üye girişliyse cihaz kimliği sunucuya kaydedilir
      unawaited(cihazKaydet());
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => cihazKaydet());
      memberNotifier.addListener(() {
        if (memberNotifier.value) cihazKaydet();
      });

      // Uygulama açıkken: Android bildirimi kendisi göstermez, biz gösteririz
      // (iPhone'da sistem gösterir; ikinci kez gösterilmesin)
      FirebaseMessaging.onMessage.listen((m) {
        final n = _notice(m);
        if (n == null) return;
        if (Platform.isIOS && m.notification != null) {
          Notices.markNotifiedIds([n.id]);
          return;
        }
        Notices.showIncoming(n);
      });

      // Bildirime dokunarak açılış (arka plandan)
      FirebaseMessaging.onMessageOpenedApp.listen(_open);

      // Bildirime dokunarak açılış (uygulama tamamen kapalıyken)
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(first));
      }
    } catch (e) {
      // Firebase yoksa (ör. Google Play Hizmetleri olmayan cihaz) 15 dakikalık kontrol devam eder
      debugPrint('firebase başlatılamadı: $e');
    }
  }

  /// Bu cihazın Firebase kimliği (koşul ve stok alarmları bu telefona gönderilir)
  static Future<String?> token() async {
    if (!ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  static String? _sonKayit;

  /// Üyenin bu telefonunu (Firebase kimliği) topluluk sunucusuna bildirir: badi mesajları buraya gelir
  static Future<void> cihazKaydet() async {
    if (!ready || !memberNotifier.value) return;
    try {
      final t = await token();
      if (t == null || t == _sonKayit || await CatchService.token() == null) return;
      await Topluluk.gonder('cihaz', {'token': t, 'platform': Topluluk.platform});
      _sonKayit = t;
    } catch (e) {
      debugPrint('cihaz kaydı: $e');
    }
  }

  static Notice? _notice(RemoteMessage m) {
    if (m.data['id'] == null) return null;
    return Notice.fromJson(Map<String, dynamic>.from(m.data));
  }

  static void _open(RemoteMessage m) {
    final n = _notice(m);
    if (n == null) return;
    Notices.markNotifiedIds([n.id]);
    Notices.open(n);
  }
}
