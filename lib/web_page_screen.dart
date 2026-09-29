import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'config.dart';
import 'main.dart';
import 'theme.dart';

/// Sitenin hesap sayfalarını (giriş, üyelik, siparişler, adresler) uygulama içinde açar.
/// Oturum çerezleri uygulamaya özeldir; şifreler uygulamada saklanmaz, doğrudan siteye gider.
class WebPageScreen extends StatefulWidget {
  final String title;
  final String route; // ör. account/login
  final String? path; // ör. mobil-gizlilik.php (sitenin kökünde bir sayfa)
  /// Giriş/üyelik sayfası: başarılı olunca uygulamanın ana ekranına dön
  final bool homeAfterLogin;
  const WebPageScreen({super.key, required this.title, this.route = '', this.path, this.homeAfterLogin = false});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _left = false;

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
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (url) {
          if (!widget.homeAfterLogin) return;
          final route = Uri.tryParse(url)?.queryParameters['route'] ?? '';
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
