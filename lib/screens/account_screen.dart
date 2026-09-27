import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../app_state.dart';
import '../config.dart';
import '../share.dart';
import '../theme.dart';
import '../web_page_screen.dart';
import 'favorites_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _open(BuildContext context, String title, String route) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => WebPageScreen(title: title, route: route)));

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
                    onPressed: () => _open(context, 'Giriş yap', 'account/login'),
                    child: const Text('Giriş yap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                    onPressed: () => _open(context, 'Üye ol', 'account/register'),
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

  Widget _group(List<Widget> children) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
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
