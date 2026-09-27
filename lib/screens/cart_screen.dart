import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../format.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sepetim')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (appState.cart.isEmpty) {
            return MessageView(
              icon: Icons.shopping_bag_outlined,
              title: 'Sepetin boş',
              body: 'Beğendiğin ürünü açıp "Sepete ekle"ye dokun.',
              actionLabel: 'Ürünlere göz at',
              onAction: () => Shell.goTo(context, 0),
            );
          }
          final remaining = appState.remainingForFreeShipping;
          final progress =
              (appState.subtotal / AppConfig.freeShippingLimit).clamp(0.0, 1.0);
          return Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining > 0
                        ? 'Ücretsiz kargoya ${tl(remaining)} kaldı'
                        : 'Kargo bedava!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2EAE7),
                      color: remaining > 0 ? Tide.samandira : Tide.yosun,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: appState.cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CartRow(appState.cart[i]),
              ),
            ),
            _Summary(remaining: remaining),
          ]);
        },
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow(this.item);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Tide.mercan, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => appState.remove(item),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
                width: 76, height: 76, child: NetImage(item.product.image)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final o in item.options)
                  Text(o.label,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7B7E))),
                const SizedBox(height: 6),
                Row(children: [
                  Text(tl(item.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  _Stepper(item),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final CartItem item;
  const _Stepper(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD3DEDB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: () => appState.setQty(item, item.qty - 1),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(item.qty == 1 ? Icons.delete_outline : Icons.remove,
                size: 18, semanticLabel: 'Azalt'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${item.qty}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        InkWell(
          onTap: () => appState.setQty(item, item.qty + 1),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.add, size: 18, semanticLabel: 'Artır'),
          ),
        ),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  final double remaining;
  const _Summary({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final shipping = remaining > 0 ? AppConfig.shippingFee : 0.0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E8E6))),
        ),
        child: Column(children: [
          _line('Ara toplam', tl(appState.subtotal)),
          _line('Kargo', shipping == 0 ? 'Bedava' : tl(shipping)),
          const Divider(height: 18),
          _line('Toplam', tl(appState.subtotal + shipping), bold: true),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Tide.samandira,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.lock_outline, size: 20),
              label: const Text('Güvenli ödemeye geç'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CheckoutScreen())),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ödeme kiyidanav.com\'un güvenli sayfasında yapılır. Kart bilgilerin uygulamaya kaydedilmez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7B7E)),
          ),
        ]),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(a,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                  fontSize: bold ? 17 : 14)),
          const Spacer(),
          Text(b,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 17 : 14)),
        ]),
      );
}
