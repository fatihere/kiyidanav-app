import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api.dart';
import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ödeme akışı:
/// 1) Temiz bir oturumla kiyidanav.com açılır (eski sepet karışmasın).
/// 2) Uygulamadaki sepet, sitenin kendi "sepete ekle" adresine aktarılır.
/// 3) Müşteri sitenin ödeme sayfasında adres ve ödemeyi tamamlar.
/// Kart bilgisi uygulamaya hiç girmez; ödeme sitenin mevcut altyapısında (PayTR/iyzico/3D Secure) olur.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Stage { preparing, transferring, paying, done, failed }

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final WebViewController _web;
  _Stage _stage = _Stage.preparing;
  int _progress = 0;
  String? _problem;
  bool _handoffStarted = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Tide.kopuk)
      ..addJavaScriptChannel('KiyidanAvApp', onMessageReceived: _onBridge)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onNavigationRequest: _guard,
        onPageFinished: _onPageFinished,
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && _stage != _Stage.paying) {
            setState(() {
              _stage = _Stage.failed;
              _problem = 'Sayfa yüklenemedi. İnternet bağlantını kontrol et.';
            });
          }
        },
      ));
    _start();
  }

  Future<void> _start() async {
    if (Api.demo) {
      setState(() {
        _stage = _Stage.failed;
        _problem =
            'Örnek ürünlerle ödeme yapılamaz. Sunucuya mobil-api.php yüklendiğinde gerçek sepet siteye aktarılır.';
      });
      return;
    }
    await WebViewCookieManager().clearCookies();
    await _web.loadRequest(Uri.parse('${AppConfig.siteUrl}index.php?route=common/home'));
  }

  /// Şifresiz (http) ve uygulama dışı adreslere gidilmez.
  /// 3D Secure için bankaların https sayfalarına izin verilir.
  NavigationDecision _guard(NavigationRequest r) {
    final u = Uri.tryParse(r.url);
    if (u == null) return NavigationDecision.prevent;
    if (u.scheme == 'about' || u.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    if (u.scheme != 'https') return NavigationDecision.prevent;
    if (u.host.endsWith(AppConfig.siteHost) &&
        (u.queryParameters['route'] ?? '').startsWith('checkout/success')) {
      appState.clearCart();
      if (mounted) setState(() => _stage = _Stage.done);
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onPageFinished(String url) async {
    final u = Uri.tryParse(url);
    if (u == null || !u.host.endsWith(AppConfig.siteHost)) return;
    if (_handoffStarted) return;
    _handoffStarted = true;
    setState(() => _stage = _Stage.transferring);

    final items = appState.cart
        .map((c) => {
              'id': c.product.id,
              'qty': c.qty,
              'opts': [
                for (final o in c.options)
                  {'o': o.optionId, 'v': o.valueId, 'cb': o.type == 'checkbox'}
              ],
            })
        .toList();

    // OpenCart 3 ve 4'ün farklı "sepete ekle" adreslerini sırayla dener.
    final js = '''
(async function(items){
  const routes = ['checkout/cart/add','checkout/cart.add','checkout/cart|add'];
  let route = null, added = 0, errors = [];
  for (const it of items) {
    const tryRoutes = route ? [route] : routes;
    for (const r of tryRoutes) {
      const body = new URLSearchParams();
      body.append('product_id', it.id);
      body.append('quantity', it.qty);
      for (const o of it.opts) {
        body.append(o.cb ? 'option['+o.o+'][]' : 'option['+o.o+']', o.v);
      }
      try {
        const res = await fetch('index.php?route=' + r, {
          method: 'POST', body: body, credentials: 'same-origin',
          headers: {'X-Requested-With': 'XMLHttpRequest'}
        });
        const j = await res.json();
        if (j && j.success) { route = r; added++; break; }
        if (j && j.error) { route = r; errors.push(it.id); break; }
      } catch (e) { /* bu adres bu sürümde yok, sıradakini dene */ }
    }
  }
  KiyidanAvApp.postMessage(JSON.stringify({added: added, total: items.length, errors: errors}));
})(${jsonEncode(items)});
''';
    try {
      await _web.runJavaScript(js);
    } catch (_) {
      _fail();
    }
  }

  void _onBridge(JavaScriptMessage m) {
    if (_stage != _Stage.transferring) return; // yalnızca aktarım sırasında dinle
    try {
      final r = jsonDecode(m.message) as Map<String, dynamic>;
      final added = (r['added'] as num?)?.toInt() ?? 0;
      final total = (r['total'] as num?)?.toInt() ?? 0;
      if (added == 0) {
        _fail();
        return;
      }
      setState(() => _stage = _Stage.paying);
      _web.loadRequest(
          Uri.parse('${AppConfig.siteUrl}index.php?route=checkout/checkout'));
      if (added < total && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${total - added} ürün stok veya seçenek nedeniyle eklenemedi. Ödeme sayfasında kontrol et.'),
        ));
      }
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _problem =
          'Sepet siteye aktarılamadı. Ürünlerin stok durumu değişmiş olabilir.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock, size: 18, color: Tide.yosun),
          SizedBox(width: 6),
          Text('Güvenli ödeme'),
        ]),
        bottom: _stage == _Stage.paying && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 3,
                    color: Tide.samandira,
                    backgroundColor: Colors.transparent),
              )
            : null,
      ),
      body: Stack(children: [
        // WebView her zaman aynı yerde durur; ödeme dışındaki aşamalarda üstü örtülür.
        Positioned.fill(child: WebViewWidget(controller: _web)),
        if (_stage != _Stage.paying)
          Positioned.fill(
            child: ColoredBox(
              color: Tide.kopuk,
              child: switch (_stage) {
                _Stage.done => MessageView(
                    icon: Icons.check_circle_outline,
                    title: 'Siparişin alındı',
                    body: 'Teşekkürler! Sipariş özetin e-postana gönderildi.',
                    actionLabel: 'Alışverişe dön',
                    onAction: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                _Stage.failed => MessageView(
                    icon: Icons.error_outline,
                    title: 'Ödemeye geçilemedi',
                    body: _problem,
                    actionLabel: 'Sepete dön',
                    onAction: () => Navigator.of(context).pop(),
                  ),
                _ => const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: Tide.derin),
                      SizedBox(height: 16),
                      Text('Sepetin güvenli ödeme sayfasına aktarılıyor'),
                    ]),
                  ),
              },
            ),
          ),
      ]),
    );
  }
}
