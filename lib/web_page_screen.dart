import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_state.dart';
import 'catches.dart';
import 'config.dart';
import 'main.dart';
import 'notices.dart';
import 'theme.dart';

/// Sitenin hesap sayfalarını (giriş, üyelik, siparişler, adresler) uygulama içinde açar.
/// Oturum çerezleri uygulamaya özeldir; şifreler uygulamada saklanmaz, doğrudan siteye gider.
class WebPageScreen extends StatefulWidget {
  final String title;
  final String route; // ör. account/login
  final String? path; // ör. mobil-gizlilik.php (sitenin kökünde bir sayfa)
  /// Giriş/üyelik sayfası: başarılı olunca uygulamanın ana ekranına dön
  final bool homeAfterLogin;
  /// Giriş başarılı olunca yalnızca bu sayfayı kapat (çağıran ekrana `true` döner)
  final bool popAfterLogin;
  const WebPageScreen(
      {super.key,
      required this.title,
      this.route = '',
      this.path,
      this.homeAfterLogin = false,
      this.popAfterLogin = false});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _left = false;
  Completer<void>? _anahtar;

  /// Girişten hemen sonra üyelik anahtarını (av bildirimi, test modülleri, günlük…) sessizce alır.
  /// Sayfa aynı oturumla mobil-av.php?oturum=1 adresini okur; en fazla 4 sn beklenir.
  Future<void> _anahtarAl() async {
    if (await CatchService.token() != null) return;
    final c = _anahtar = Completer<void>();
    try {
      await _web.runJavaScript(
          "fetch('/${CatchService.sessionPath}',{credentials:'include'}).then(function(r){return r.text()})"
          ".then(function(t){var m=/id=\"t\"[^>]*>([^<]*)</.exec(t);KiyidanAvAnahtar.postMessage(m?m[1]:'')})"
          ".catch(function(){KiyidanAvAnahtar.postMessage('')})");
      await c.future.timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Sitenin ana sayfası mı? (logo, "Anasayfa" bağlantısı)
  static bool _isSiteHome(Uri u) {
    if (!u.host.endsWith(AppConfig.siteHost)) return false;
    final p = u.path;
    final route = u.queryParameters['route'];
    return (p.isEmpty || p == '/' || p == '/index.php') && (route == null || route == 'common/home');
  }

  void _leaveToHome({String? message}) {
    if (_left) return;
    _left = true;
    goHome();
    if (message != null) {
      final ctx = navKey.currentContext;
      if (ctx != null) ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Tide.zemin)
      ..addJavaScriptChannel('KiyidanAvAnahtar', onMessageReceived: (m) async {
        final t = m.message.trim();
        if (t.contains('.')) await CatchService.saveToken(t);
        final c = _anahtar;
        if (c != null && !c.isCompleted) c.complete();
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (url) async {
          final route = Uri.tryParse(url)?.queryParameters['route'] ?? '';
          if (route == 'account/account' || route == 'account/success') await _anahtarAl();
          // Üyelik durumu: hesap sayfası yalnızca giriş yapılmışken açılır (değilse site girişe yönlendirir)
          if (route == 'account/account' || route == 'account/success') appState.setMember(true);
          if (route == 'account/logout') {
            appState.setMember(false);
            CatchService.saveToken(null); // av bildirimi anahtarı da silinsin
          }
          if (widget.popAfterLogin && (route == 'account/account' || route == 'account/success')) {
            if (!_left && mounted) {
              _left = true;
              Navigator.of(context).pop(true);
            }
            return;
          }
          if (!widget.homeAfterLogin) return;
          // Başarılı girişte site hesap sayfasına, üyelikte başarı sayfasına yönlendirir
          if (route == 'account/account' || route == 'account/success') {
            _leaveToHome(message: 'Giriş yapıldı, hoş geldin!');
          }
        },
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null || u.scheme != 'https') return NavigationDecision.prevent;
          if (r.isMainFrame && _isSiteHome(u)) {
            _leaveToHome();
            return NavigationDecision.prevent;
          }
          if (u.host.endsWith(AppConfig.siteHost)) return NavigationDecision.navigate;
          // Site dışı bağlantılar (WhatsApp, sosyal medya) telefonun kendi uygulamasında açılır
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.path != null
          ? '${AppConfig.siteUrl}${widget.path}'
          : '${AppConfig.siteUrl}index.php?route=${widget.route}'));
    // Android: sayfadaki "fotoğraf seç" alanları (av araçları: tür tanıma, turnuva) telefonun kamerası/galerisiyle çalışsın
    final pf = _web.platform;
    if (pf is AndroidWebViewController) {
      pf.setOnShowFileSelector(_dosyaSec);
    }
  }

  Future<List<String>> _dosyaSec(FileSelectorParams p) async {
    final tur = p.acceptTypes.join(',').toLowerCase();
    if (tur.isNotEmpty && !tur.contains('image')) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Bu dosyayı kiyidanav.com üzerinden bilgisayardan ya da telefon tarayıcısından yükleyebilirsin.')));
      }
      return const [];
    }
    try {
      final picker = ImagePicker();
      if (p.mode == FileSelectorMode.openMultiple) {
        final xs = await picker.pickMultiImage(maxWidth: 2000, imageQuality: 85, limit: 3);
        return xs.map((x) => Uri.file(x.path).toString()).toList();
      }
      final x = await picker.pickImage(
          source: p.isCaptureEnabled ? ImageSource.camera : ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
      return x == null ? const [] : [Uri.file(x.path).toString()];
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                      value: _progress / 100, minHeight: 3, color: Tide.turuncu, backgroundColor: Colors.transparent),
                )
              : null,
        ),
        body: WebViewWidget(controller: _web),
      ),
    );
  }
}
