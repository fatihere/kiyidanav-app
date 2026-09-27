import 'package:flutter/material.dart';

import 'app_state.dart';
import 'format.dart';
import 'models.dart';
import 'screens/product_screen.dart';
import 'theme.dart';

class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFF1EFE6),
      alignment: Alignment.center,
      child: const Icon(Icons.phishing, color: Tide.misina, size: 36),
    );
    final u = url;
    if (u == null || !u.startsWith('https://')) return placeholder;
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (c, child, p) => p == null ? child : placeholder,
    );
  }
}

class PriceView extends StatelessWidget {
  final double price;
  final double? special;
  final bool large;
  const PriceView(
      {super.key, required this.price, this.special, this.large = false});

  @override
  Widget build(BuildContext context) {
    final main = TextStyle(
      fontSize: large ? 26 : 16,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: special != null ? Tide.mercan : Tide.kaya,
    );
    final old = TextStyle(
      fontSize: large ? 15 : 12,
      color: Tide.misina,
      decoration: TextDecoration.lineThrough,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        Text(tl(special ?? price), style: main),
        if (special != null) Text(tl(price), style: old),
      ],
    );
  }
}

class ProductTile extends StatelessWidget {
  final ProductCard p;
  const ProductTile(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductScreen(id: p.id, preview: p))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: Colors.white, padding: const EdgeInsets.all(6), child: NetImage(p.image, fit: BoxFit.contain)),
                if (!p.inStock)
                  Container(
                    color: Colors.white.withAlpha(150),
                    alignment: Alignment.center,
                    child: const Text('Tükendi',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Tide.kaya)),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: ListenableBuilder(
                    listenable: appState,
                    builder: (_, __) {
                      final fav = appState.isFavorite(p.id);
                      return IconButton(
                        tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                        onPressed: () => appState.toggleFavorite(p),
                        icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                            color: fav ? Tide.samandira : Tide.kaya),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(220)),
                      );
                    },
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.brand != null)
                    Text(p.brand!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Tide.zeytin)),
                  const SizedBox(height: 2),
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, height: 1.3)),
                  const SizedBox(height: 6),
                  PriceView(price: p.price, special: p.special),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yatay kaydırılan ürün şeridi (ana sayfa vitrinleri)
class ProductCarousel extends StatelessWidget {
  final List<ProductCard> items;
  const ProductCarousel(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 292,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 158, child: ProductTile(items[i])),
      ),
    );
  }
}

/// Ekran genişliğine göre ürün ızgarası (sliver)
class ProductGrid extends StatelessWidget {
  final List<ProductCard> items;
  const ProductGrid(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 900 ? 4 : (w > 600 ? 3 : 2);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductTile(items[i]),
          childCount: items.length,
        ),
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageView(
      {super.key,
      required this.icon,
      required this.title,
      this.body,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Tide.misina),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5B6B6E))),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF7C4AA)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: Tide.samandira, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Örnek ürünler gösteriliyor. Sunucuya mobil-api.php yüklenince gerçek katalog gelir.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }
}
