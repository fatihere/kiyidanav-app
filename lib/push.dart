import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';

import 'notices.dart';

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
      await FirebaseMessaging.instance.subscribeToTopic(pushTopic);
      ready = true;

      // Uygulama açıkken: Android bildirimi kendisi göstermez, biz gösteririz
      FirebaseMessaging.onMessage.listen((m) {
        final n = _notice(m);
        if (n != null) Notices.showIncoming(n);
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
