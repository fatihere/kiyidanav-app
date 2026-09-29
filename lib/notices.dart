import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'bait_card.dart';
import 'config.dart';
import 'main.dart';
import 'models.dart';
import 'screens/category_screen.dart';
import 'screens/product_screen.dart';
import 'sea.dart';
import 'solunar.dart';
import 'theme.dart';

/// Tüm uygulamadan sayfa açabilmek için (bildirime dokununca)
final navKey = GlobalKey<NavigatorState>();

/// Yönetim panelinden gönderilen bildirim / kampanya
class Notice {
  final String id;
  final String type; // rapor | urun | kategori | kampanya
  final String title;
  final String body;
  final String image;
  final String target; // ürün/kategori no veya web adresi
  final String date;

  const Notice(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      this.image = '',
      this.target = '',
      this.date = ''});

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: '${j['id'] ?? ''}',
        type: '${j['tip'] ?? 'kampanya'}',
        title: '${j['baslik'] ?? ''}',
        body: '${j['metin'] ?? ''}',
        image: '${j['gorsel'] ?? ''}',
        target: '${j['hedef'] ?? ''}',
        date: '${j['tarih'] ?? ''}',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'tip': type, 'baslik': title, 'metin': body, 'gorsel': image, 'hedef': target, 'tarih': date};

  bool get hasImage => image.startsWith('https://');
}

class Notices {
  static const _seenKey = 'notice_seen';
  static const _notifiedKey = 'notice_notified';
  static const _popupKey = 'notice_popup';
  static const _taskName = 'kiyidanav-bildirim';

  static final plugin = FlutterLocalNotificationsPlugin();

  /// Sadece gerçek uygulamada (main) açılır; testlerde ağ/eklenti çağrısı yapılmaz
  static bool enabled = false;
  static final items = ValueNotifier<List<Notice>>(const []);
  static final unread = ValueNotifier<int>(0);

  static const _channel = AndroidNotificationDetails(
    'kiyidanav_duyuru',
    'Kampanyalar ve av raporu',
    channelDescription: 'KıyıdanAv kampanya, ürün ve günlük av raporu bildirimleri',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_notify',
    color: Tide.turuncu,
  );

  // ---------------- Sunucu ----------------
  static Future<List<Notice>> fetch() async {
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'bildirimler'});
    final res = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    final j = jsonDecode(res.body);
    if (j is! Map || j['ok'] != true) return const [];
    return ((j['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Notice.fromJson(Map<String, dynamic>.from(e)))
        .where((n) => n.id.isNotEmpty && n.title.isNotEmpty)
        .toList();
  }

  // ---------------- Başlatma ----------------
  static Future<void> initPlugin({bool foreground = false}) async {
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
      onDidReceiveNotificationResponse: foreground ? (r) => _openPayload(r.payload) : null,
    );
  }

  /// Uygulama açılışında: bildirim eklentisi, izin, arka plan görevi, açılışı bildirimle olduysa yönlendirme
  static Future<void> start() async {
    try {
      await initPlugin(foreground: true);
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch?.notificationResponse?.payload;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(payload));
      }
    } catch (e) {
      debugPrint('bildirim eklentisi: $e');
    }
    try {
      await Workmanager().initialize(noticeDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('arka plan görevi: $e');
    }
  }

  /// Android 13+ bildirim izni (ilk açılışta bir kez sorulur)
  static Future<void> askPermission() async {
    try {
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  // ---------------- Uygulama içi ----------------
  static Future<void> refresh({bool popup = true}) async {
    if (!enabled) return;
    List<Notice> list;
    try {
      list = await fetch();
    } catch (_) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    final seen = (p.getStringList(_seenKey) ?? const []).toSet();
    items.value = list;
    unread.value = list.where((n) => !seen.contains(n.id)).length;
    // Uygulama açıkken gelenler için telefon bildirimi tekrar çıkmasın
    final notified = (p.getStringList(_notifiedKey) ?? const []).toSet()..addAll(list.map((n) => n.id));
    await p.setStringList(_notifiedKey, notified.take(200).toList());

    if (!popup) return;
    final popped = (p.getStringList(_popupKey) ?? const []).toSet();
    final fresh = list.where((n) => !seen.contains(n.id) && !popped.contains(n.id) && n.type != 'rapor');
    if (fresh.isEmpty) return;
    final n = fresh.first;
    popped.add(n.id);
    await p.setStringList(_popupKey, popped.take(200).toList());
    // Navigator'ın altındaki bir bağlam gerekir (overlay)
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx != null && ctx.mounted) {
      showDialog(context: ctx, builder: (_) => NoticeDialog(n));
    }
  }

  static Future<void> markAllSeen() async {
    final p = await SharedPreferences.getInstance();
    final seen = (p.getStringList(_seenKey) ?? const []).toSet()..addAll(items.value.map((n) => n.id));
    await p.setStringList(_seenKey, seen.take(300).toList());
    unread.value = 0;
  }

  static Future<void> _openPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      open(Notice.fromJson(Map<String, dynamic>.from(jsonDecode(payload) as Map)));
    } catch (_) {}
  }

  /// Bildirimin hedefini açar
  static void open(Notice n) {
    final nav = navKey.currentState;
    switch (n.type) {
      case 'rapor':
        nav?.popUntil((r) => r.isFirst);
        shellTab.value = Shell.tabReport;
        break;
      case 'urun':
        final id = int.tryParse(n.target);
        if (id != null && id > 0) nav?.push(MaterialPageRoute(builder: (_) => ProductScreen(id: id)));
        break;
      case 'kategori':
        final id = int.tryParse(n.target);
        if (id != null && id > 0) {
          nav?.push(MaterialPageRoute(builder: (_) => CategoryScreen(category: Category(id: id, name: n.title))));
        }
        break;
      default:
        final u = Uri.tryParse(n.target);
        if (u != null && u.scheme == 'https') {
          if (u.host.endsWith(AppConfig.siteHost) && u.queryParameters['product_id'] != null) {
            final id = int.tryParse(u.queryParameters['product_id']!);
            if (id != null) {
              nav?.push(MaterialPageRoute(builder: (_) => ProductScreen(id: id)));
              return;
            }
          }
          launchUrl(u, mode: LaunchMode.externalApplication);
        } else if (n.target.isNotEmpty) {
          nav?.push(MaterialPageRoute(
              builder: (_) => SearchResultsScreen(query: n.target, title: n.title)));
        }
    }
  }

  // ---------------- Arka plan ----------------
  /// Uygulama kapalıyken yaklaşık 30 dakikada bir çalışır, yeni bildirimleri telefona düşürür
  static Future<void> backgroundCheck() async {
    final list = await fetch();
    final p = await SharedPreferences.getInstance();
    final first = !p.containsKey(_notifiedKey);
    final notified = (p.getStringList(_notifiedKey) ?? const []).toSet();
    final fresh = list.where((n) => !notified.contains(n.id)).toList();
    notified.addAll(list.map((n) => n.id));
    await p.setStringList(_notifiedKey, notified.take(200).toList());
    // İlk kurulumda eski bildirimleri topluca göstermeyelim
    if (first || fresh.isEmpty) return;
    await initPlugin();
    var shown = 0;
    for (final n in fresh.take(3)) {
      var body = n.body;
      if (n.type == 'rapor') body = await _reportLine(p) ?? body;
      AndroidNotificationDetails details = _channel;
      if (n.hasImage) {
        final bytes = await _image(n.image);
        if (bytes != null) {
          details = AndroidNotificationDetails(
            _channel.channelId,
            _channel.channelName,
            channelDescription: _channel.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notify',
            color: Tide.turuncu,
            styleInformation: BigPictureStyleInformation(ByteArrayAndroidBitmap(bytes),
                contentTitle: n.title, summaryText: body.isEmpty ? null : body),
          );
        }
      } else if (body.length > 40) {
        details = AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notify',
          color: Tide.turuncu,
          styleInformation: BigTextStyleInformation(body),
        );
      }
      await plugin.show(
        id: n.id.hashCode & 0x7fffffff,
        title: n.title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        payload: jsonEncode(n.toJson()),
      );
      shown++;
    }
    debugPrint('arka plan: $shown bildirim');
  }

  /// "Kartal: av verimliliği %72 (Verimli) — Uygun, biraz ağır takım tercih et"
  static Future<String?> _reportLine(SharedPreferences p) async {
    try {
      final name = p.getString('spot_v2');
      final match = spots.where((s) => s.name == name);
      final spot = match.isNotEmpty ? match.first : spots[5];
      final f = await SeaService.fetchWeek(spot);
      final score = FishingScore.compute(DateTime.now(),
          windKmh: f.now.effectiveWind, waveM: f.now.effectiveWave, pressureTrend: f.pressureTrend, rainMm: f.now.rainDay);
      return '${spot.name}: av verimliliği %$score (${FishingScore.label(score)}) — ${f.now.verdict}';
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _image(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 && r.bodyBytes.length < 1500000) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}

@pragma('vm:entry-point')
void noticeDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Notices.backgroundCheck();
    } catch (e) {
      debugPrint('arka plan hata: $e');
    }
    return true;
  });
}

/// Uygulama açılınca yeni kampanya için gösterilen pencere
class NoticeDialog extends StatelessWidget {
  final Notice n;
  const NoticeDialog(this.n, {super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (n.hasImage)
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(n.image,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Tide.zemin)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Text(n.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        if (n.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Text(n.body, style: const TextStyle(fontSize: 14.5, height: 1.45)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
            if (n.type != 'kampanya' || n.target.isNotEmpty)
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Notices.open(n);
                  },
                  child: const Text('İncele'),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// 🔔 Bildirimler kutusu
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  @override
  void initState() {
    super.initState();
    Notices.refresh(popup: false).whenComplete(Notices.markAllSeen);
  }

  IconData _icon(String t) {
    switch (t) {
      case 'rapor':
        return Icons.set_meal;
      case 'urun':
        return Icons.phishing;
      case 'kategori':
        return Icons.category_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ValueListenableBuilder<List<Notice>>(
        valueListenable: Notices.items,
        builder: (_, list, __) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Şu an yeni bir kampanya veya duyuru yok.', textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = list[i];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Notices.open(n),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: n.hasImage
                              ? Image.network(n.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(_icon(n.type), color: Tide.zeytin))
                              : Container(
                                  color: const Color(0xFFF1EFE6),
                                  child: Icon(_icon(n.type), color: Tide.zeytin, size: 32)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(n.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF55554A))),
                              ],
                              if (n.date.length >= 10) ...[
                                const SizedBox(height: 4),
                                Text(n.date.substring(0, 10),
                                    style: const TextStyle(fontSize: 11.5, color: Tide.misina)),
                              ],
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Başlıktaki zil simgesi (okunmamış sayısıyla)
class NoticeBell extends StatelessWidget {
  const NoticeBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Notices.unread,
      builder: (_, n, __) => IconButton(
        tooltip: 'Bildirimler',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoticesScreen())),
        icon: Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          backgroundColor: Tide.turuncu,
          child: const Icon(Icons.notifications_none, color: Tide.zeytinKoyu, size: 27),
        ),
      ),
    );
  }
}

/// Ana sayfadaki kampanya afişleri (görselli bildirimler)
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Notice>>(
      valueListenable: Notices.items,
      builder: (_, list, __) {
        final banners = list.where((n) => n.hasImage && n.type != 'rapor').take(6).toList();
        if (banners.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            height: 150,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: banners.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Notices.open(banners[i]),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(banners[i].image,
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Tide.zeytin)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xAA000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        child: Text(banners[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
