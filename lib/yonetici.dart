import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'catches.dart';
import 'config.dart';
import 'ekran_koruma.dart';
import 'theme.dart';

/// 1.13.0 — Uygulamada yönetici girişi.
/// OpenCart yönetici kullanıcı adı ve şifresiyle giriş yapılır (şifre uygulamada saklanmaz, yalnızca
/// kiyidanav.com/mobil-yonetim.php'ye gider). Sunucu 12 saatlik bir yönetim oturumu açar; Mobil uygulama,
/// Modüller, Topluluk ve Etkinlik panelleri uygulamanın içindeki tarayıcıda bu oturumla açılır.
/// Yönetici girişli telefonda ekran görüntüsü engeli kalkar.
class YoneticiPanel {
  final String id, ad, alt, url;
  const YoneticiPanel(this.id, this.ad, this.alt, this.url);

  factory YoneticiPanel.fromJson(Map j) =>
      YoneticiPanel('${j['id'] ?? ''}', '${j['ad'] ?? ''}', '${j['alt'] ?? ''}', '${j['url'] ?? ''}');

  Map<String, String> toJson() => {'id': id, 'ad': ad, 'alt': alt, 'url': url};

  IconData get ikon => switch (id) {
        'mobil' => Icons.phone_iphone,
        'moduller' => Icons.extension_outlined,
        'topluluk' => Icons.forum_outlined,
        'etkinlik' => Icons.event_outlined,
        'araclar' => Icons.handyman_outlined,
        'opencart' => Icons.storefront_outlined,
        _ => Icons.admin_panel_settings_outlined,
      };
}

class YoneticiOturum {
  final String oturum;
  final String ad;
  final int gecerlilik; // unix saniye
  final List<YoneticiPanel> paneller;
  const YoneticiOturum(this.oturum, this.ad, this.gecerlilik, this.paneller);

  bool get gecerli => gecerlilik * 1000 > DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() =>
      {'oturum': oturum, 'ad': ad, 'gecerlilik': gecerlilik, 'paneller': paneller.map((p) => p.toJson()).toList()};

  static YoneticiOturum? fromJson(Object? j) {
    if (j is! Map) return null;
    final o = '${j['oturum'] ?? ''}';
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(o)) return null;
    final g = j['gecerlilik'];
    return YoneticiOturum(
      o,
      '${j['ad'] ?? 'Yönetici'}',
      g is num ? g.toInt() : int.tryParse('$g') ?? 0,
      ((j['paneller'] as List?) ?? const []).whereType<Map>().map(YoneticiPanel.fromJson).where((p) => p.url.startsWith('https://')).toList(),
    );
  }
}

class Yonetici {
  static const _anahtar = 'yonetici_oturum_v1';
  static final aktif = ValueNotifier<YoneticiOturum?>(null);
  static Uri get _uri => Uri.parse('${AppConfig.siteUrl}mobil-yonetim.php');

  static bool get girisli => aktif.value?.gecerli ?? false;

  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(_anahtar);
      final o = ham == null ? null : YoneticiOturum.fromJson(jsonDecode(ham));
      if (o != null && o.gecerli) {
        aktif.value = o;
      } else if (ham != null) {
        await p.remove(_anahtar);
      }
    } catch (_) {}
  }

  static Future<void> _kaydet(YoneticiOturum? o) async {
    aktif.value = o;
    try {
      final p = await SharedPreferences.getInstance();
      if (o == null) {
        await p.remove(_anahtar);
      } else {
        await p.setString(_anahtar, jsonEncode(o.toJson()));
      }
    } catch (_) {}
    // Yönetici telefonunda ekran görüntüsü alınabilsin; çıkışta panel ayarı geri gelir
    await EkranKoruma.uygula(zorla: true);
  }

  /// Giriş yapar; hata mesajı döner (başarıda null)
  static Future<String?> giris(String kullanici, String sifre) async {
    try {
      final av = await CatchService.token();
      final r = await http
          .post(_uri,
              headers: {'Accept': 'application/json', if (av != null) 'X-Av-Anahtar': av},
              body: {'a': 'giris', 'kullanici': kullanici.trim(), 'sifre': sifre})
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true) {
        final o = YoneticiOturum.fromJson(j);
        if (o == null) return 'Sunucu beklenmeyen bir yanıt verdi.';
        await _kaydet(o);
        return null;
      }
      return j is Map ? '${j['error'] ?? 'Giriş yapılamadı.'}' : 'Giriş yapılamadı.';
    } on TimeoutException {
      return 'Bağlantı çok yavaş. Tekrar dene.';
    } catch (_) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';
    }
  }

  /// Oturum sunucuda hâlâ açık mı? Kapandıysa yerel kaydı siler.
  static Future<bool> denetle() async {
    final o = aktif.value;
    if (o == null) return false;
    try {
      final r = await http.post(_uri, body: {'a': 'durum', 'oturum': o.oturum}).timeout(const Duration(seconds: 12));
      if (r.statusCode == 401) {
        await _kaydet(null);
        return false;
      }
    } catch (_) {}
    return girisli;
  }

  static Future<void> cikis() async {
    final o = aktif.value;
    if (o != null) {
      try {
        await http.post(_uri, body: {'a': 'cikis', 'oturum': o.oturum}).timeout(const Duration(seconds: 8));
      } catch (_) {}
      try {
        await WebViewCookieManager().clearCookies();
      } catch (_) {}
    }
    await _kaydet(null);
  }

  /// Hesabım'daki giriş noktası: girişliyse paneller, değilse giriş formu
  static Future<void> ac(BuildContext context) async {
    if (girisli) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YoneticiEkrani()));
      return;
    }
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const YoneticiGirisEkrani()));
    if (ok == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YoneticiEkrani()));
    }
  }
}

// =====================================================================
// Giriş formu
// =====================================================================
class YoneticiGirisEkrani extends StatefulWidget {
  const YoneticiGirisEkrani({super.key});

  @override
  State<YoneticiGirisEkrani> createState() => _YoneticiGirisEkraniState();
}

class _YoneticiGirisEkraniState extends State<YoneticiGirisEkrani> {
  final _kul = TextEditingController();
  final _sifre = TextEditingController();
  bool _mesgul = false;
  bool _gizli = true;
  String? _hata;

  @override
  void dispose() {
    _kul.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _gir() async {
    if (_kul.text.trim().isEmpty || _sifre.text.isEmpty) {
      setState(() => _hata = 'Kullanıcı adı ve şifreyi yaz.');
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final h = await Yonetici.giris(_kul.text, _sifre.text);
    if (!mounted) return;
    _sifre.clear();
    setState(() {
      _mesgul = false;
      _hata = h;
    });
    if (h == null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici girişi')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 56, color: Tide.derin),
        const SizedBox(height: 10),
        const Text(
          'kiyidanav.com yönetim paneli kullanıcı adın ve şifrenle giriş yap. Şifren uygulamada saklanmaz; '
          'giriş 12 saat geçerlidir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF55544A)),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _kul,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: 'Kullanıcı adı', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sifre,
          obscureText: _gizli,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _gir(),
          decoration: InputDecoration(
            labelText: 'Şifre',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _gizli ? 'Şifreyi göster' : 'Şifreyi gizle',
              onPressed: () => setState(() => _gizli = !_gizli),
              icon: Icon(_gizli ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_hata!, style: const TextStyle(color: Tide.mercan, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tide.derin),
            onPressed: _mesgul ? null : _gir,
            child: Text(_mesgul ? 'Giriş yapılıyor…' : 'Giriş yap'),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Panel listesi
// =====================================================================
class YoneticiEkrani extends StatefulWidget {
  const YoneticiEkrani({super.key});

  @override
  State<YoneticiEkrani> createState() => _YoneticiEkraniState();
}

class _YoneticiEkraniState extends State<YoneticiEkrani> {
  @override
  void initState() {
    super.initState();
    Yonetici.denetle().then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Yönetici oturumu kapanmış. Yeniden giriş yap.')));
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<YoneticiOturum?>(
      valueListenable: Yonetici.aktif,
      builder: (context, o, _) => Scaffold(
        appBar: AppBar(title: const Text('Yönetim')),
        body: o == null
            ? const Center(child: Text('Yönetici girişi yok.'))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('Merhaba ${o.ad}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Tide.derin)),
                const SizedBox(height: 4),
                const Text('Bu telefonda ekran görüntüsü alabilirsin. Paneller uygulamanın içinde açılır.',
                    style: TextStyle(color: Color(0xFF66655A), fontSize: 13)),
                const SizedBox(height: 14),
                for (final p in o.paneller)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Tide.derin, child: Icon(p.ikon, color: Colors.white)),
                      title: Text(p.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: p.alt.isEmpty ? null : Text(p.alt),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => YoneticiPanelEkrani(panel: p, oturum: o.oturum))),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Tide.mercan),
                  onPressed: () async {
                    await Yonetici.cikis();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Yönetici oturumunu kapat'),
                ),
              ]),
      ),
    );
  }
}

// =====================================================================
// Panel (uygulama içi tarayıcı, yönetim oturumu çereziyle)
// =====================================================================
class YoneticiPanelEkrani extends StatefulWidget {
  final YoneticiPanel panel;
  final String oturum;
  const YoneticiPanelEkrani({super.key, required this.panel, required this.oturum});

  @override
  State<YoneticiPanelEkrani> createState() => _YoneticiPanelEkraniState();
}

class _YoneticiPanelEkraniState extends State<YoneticiPanelEkrani> {
  final _web = WebViewController();
  int _yuzde = 0;

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  Future<void> _hazirla() async {
    final c = WebViewCookieManager();
    for (final alan in ['www.kiyidanav.com', 'kiyidanav.com']) {
      try {
        await c.setCookie(WebViewCookie(name: 'OCSESSID', value: widget.oturum, domain: alan, path: '/'));
      } catch (_) {}
    }
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _yuzde = p);
        },
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.scheme == 'https' && u.host.endsWith(AppConfig.siteHost)) return NavigationDecision.navigate;
          if (u.scheme == 'https' || u.scheme == 'mailto' || u.scheme == 'tel') {
            launchUrl(u, mode: LaunchMode.externalApplication);
          }
          return NavigationDecision.prevent;
        },
      ));
    final pf = _web.platform;
    if (pf is AndroidWebViewController) pf.setOnShowFileSelector(_dosyaSec);
    await _web.loadRequest(Uri.parse(widget.panel.url));
  }

  /// Paneldeki dosya alanları (bildirim görseli vb.) için galeri
  Future<List<String>> _dosyaSec(FileSelectorParams p) async {
    final tur = p.acceptTypes.join(',').toLowerCase();
    if (tur.isNotEmpty && !tur.contains('image')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu dosya türü telefondan seçilemiyor; bilgisayardan yükle.')));
      }
      return const [];
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    return x == null ? const [] : [Uri.file(x.path).toString()];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.panel.ad, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Yenile', onPressed: () => _web.reload(), icon: const Icon(Icons.refresh)),
        ],
        bottom: _yuzde < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _yuzde / 100, minHeight: 3, color: Tide.turuncu),
              )
            : null,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _web.canGoBack()) {
            await _web.goBack();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: WebViewWidget(controller: _web),
      ),
    );
  }
}
