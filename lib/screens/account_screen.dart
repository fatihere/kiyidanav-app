import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../app_state.dart';
import '../config.dart';
import '../notices.dart';
import '../share.dart';
import '../theme.dart';
import '../web_page_screen.dart';
import 'favorites_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _open(BuildContext context, String title, String route, {bool homeAfterLogin = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WebPageScreen(title: title, route: route, homeAfterLogin: homeAfterLogin)));

  void _openUrl(BuildContext context, String title, String path) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => WebPageScreen(title: title, path: path)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Tide.zeytin, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('KıyıdanAv müşteri hesabı',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Siparişlerini takip et, adreslerini kaydet, hızlı öde.',
                  style: TextStyle(color: Color(0xFFEDEBDD), fontSize: 13.5)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                    onPressed: () => _open(context, 'Giriş yap', 'account/login', homeAfterLogin: true),
                    child: const Text('Giriş yap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                    onPressed: () => _open(context, 'Üye ol', 'account/register', homeAfterLogin: true),
                    child: const Text('Üye ol'),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          _group([
            _tile(Icons.person_outline, 'Hesap bilgilerim', () => _open(context, 'Hesabım', 'account/account')),
            _tile(Icons.receipt_long_outlined, 'Siparişlerim', () => _open(context, 'Siparişlerim', 'account/order')),
            _tile(Icons.local_shipping_outlined, 'Adreslerim', () => _open(context, 'Adreslerim', 'account/address')),
            ListenableBuilder(
              listenable: appState,
              builder: (_, __) => _tile(
                Icons.favorite_border,
                'Favorilerim (${appState.favorites.length})',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _group([
            _tile(Icons.chat_outlined, 'WhatsApp destek hattı', () {
              launchUrl(Uri.parse('https://wa.me/${AppConfig.whatsapp}'), mode: LaunchMode.externalApplication);
            }),
            _tile(Icons.call_outlined, 'Bizi arayın: ${Api.config.phone}', () {
              launchUrl(Uri.parse('tel:${Api.config.phone.replaceAll(' ', '')}'));
            }),
            _tile(Icons.share_outlined, 'Uygulamayı paylaş', Sharer.app),
          ]),
          const SizedBox(height: 16),
          _group([
            _tile(Icons.notifications_none, 'Bildirimler ve kampanyalar',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoticesScreen()))),
            const _NoticePermissionTile(),
          ]),
          const SizedBox(height: 16),
          _group([
            _tile(Icons.privacy_tip_outlined, 'Gizlilik politikası', () => _openUrl(context, 'Gizlilik politikası', 'mobil-gizlilik.php')),
            _tile(Icons.person_remove_outlined, 'Hesabımı sil', () => _openUrl(context, 'Hesabımı sil', 'hesap-sil.php')),
            _tile(Icons.logout, 'Çıkış yap', () => _open(context, 'Çıkış', 'account/logout')),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Giriş ve ödeme bilgileri doğrudan kiyidanav.com\'un güvenli sayfalarına gider; uygulama şifre veya kart bilgisi saklamaz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF77766A)),
          ),
        ],
      ),
    );
  }

  // Material: satırlara dokununca dalga efekti görünsün (renkli kutu efekti gizliyordu)
  Widget _group(List<Widget> children) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ]),
      );

  Widget _tile(IconData icon, String text, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: Tide.zeytinKoyu),
        title: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Tide.misina),
        onTap: onTap,
      );
}

/// Bildirim izni durumu (açık/kapalı) — dokununca izin ister ve deneme bildirimi gönderir
class _NoticePermissionTile extends StatefulWidget {
  const _NoticePermissionTile();

  @override
  State<_NoticePermissionTile> createState() => _NoticePermissionTileState();
}

class _NoticePermissionTileState extends State<_NoticePermissionTile> with WidgetsBindingObserver {
  bool? _on;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Telefon ayarlarından dönünce durumu yenile
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await Notices.permissionEnabled();
    if (mounted) setState(() => _on = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = _on == true;
    return ListTile(
      leading: Icon(on ? Icons.notifications_active : Icons.notifications_off_outlined,
          color: on ? const Color(0xFF1F8B4C) : Tide.turuncu),
      title: Text(on ? 'Bildirimler açık — deneme gönder' : 'Bildirimleri aç'),
      subtitle: Text(on ? 'Kampanya ve mera bilgisi bildirimleri gelir' : 'Şu an kapalı: kampanyaları kaçırırsın'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Notices.checkAndTest(context);
        await _check();
      },
    );
  }
}
