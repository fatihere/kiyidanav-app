import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ProductScreen extends StatefulWidget {
  final int id;
  final ProductCard? preview;
  const ProductScreen({super.key, required this.id, this.preview});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<ProductDetail> _future;
  final Map<int, int> _selected = {}; // optionId -> valueId
  int _qty = 1;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<ProductDetail> _fetch() => Api.product(widget.id).then((p) {
        _qty = p.minimum;
        return p;
      });

  double _unitPrice(ProductDetail p) {
    var price = p.special ?? p.price;
    for (final o in p.options) {
      final v = _selected[o.id];
      if (v == null) continue;
      for (final val in o.values) {
        if (val.id == v) price += val.price;
      }
    }
    return price;
  }

  void _addToCart(ProductDetail p) {
    final missing = p.options
        .where((o) => o.required && !_selected.containsKey(o.id))
        .map((o) => o.name)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lütfen seç: ${missing.join(', ')}')));
      return;
    }
    final opts = <SelectedOption>[];
    for (final o in p.options) {
      final v = _selected[o.id];
      if (v == null) continue;
      final val = o.values.firstWhere((e) => e.id == v);
      opts.add(SelectedOption(
          optionId: o.id,
          valueId: v,
          type: o.type,
          label: '${o.name}: ${val.name}'));
    }
    appState.addToCart(CartItem(
      product: p.toCard(),
      options: opts,
      unitPrice: _unitPrice(p),
      qty: _qty,
    ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Sepete eklendi'),
        action: SnackBarAction(
          label: 'Sepete git',
          textColor: Tide.samandira,
          onPressed: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            Shell.goTo(context, 3);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductDetail>(
      future: _future,
      builder: (context, snap) {
        final p = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.brand ?? widget.preview?.brand ?? ''),
            actions: [
              if (p != null)
                ListenableBuilder(
                  listenable: appState,
                  builder: (_, __) {
                    final fav = appState.isFavorite(p.id);
                    return IconButton(
                      tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? Tide.samandira : null),
                      onPressed: () => appState.toggleFavorite(p.toCard()),
                    );
                  },
                ),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator(color: Tide.derin))
              : snap.hasError
                  ? MessageView(
                      icon: Icons.error_outline,
                      title: 'Ürün açılamadı',
                      body: snap.error.toString(),
                      actionLabel: 'Tekrar dene',
                      onAction: () =>
                          setState(() => _future = _fetch()),
                    )
                  : _body(p!),
          bottomNavigationBar: p == null ? null : _bottomBar(p),
        );
      },
    );
  }

  Widget _body(ProductDetail p) {
    final images = p.images.isEmpty ? <String?>[null] : p.images;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(children: [
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _imageIndex = i),
              itemBuilder: (_, i) => Container(
                  color: Colors.white,
                  child: NetImage(images[i], fit: BoxFit.contain)),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _imageIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _imageIndex ? Tide.derin : Tide.misina,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              PriceView(price: p.price, special: p.special, large: true),
              const SizedBox(height: 8),
              Row(children: [
                Icon(p.inStock ? Icons.check_circle : Icons.cancel,
                    size: 18, color: p.inStock ? Tide.yosun : Tide.mercan),
                const SizedBox(width: 6),
                Text(p.inStock ? 'Stokta, hemen kargoda' : 'Şu an stokta yok',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: p.inStock ? Tide.yosun : Tide.mercan)),
                if (p.model != null) ...[
                  const Spacer(),
                  Text('Model: ${p.model}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7B7E))),
                ],
              ]),
              for (final o in p.options) _optionPicker(o),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Ürün hakkında',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(p.description,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionPicker(ProductOption o) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.required ? '${o.name} seç' : '${o.name} (isteğe bağlı)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: o.values.map((v) {
              final sel = _selected[o.id] == v.id;
              final extra = v.price == 0
                  ? ''
                  : ' (${v.price > 0 ? '+' : ''}${tl(v.price)})';
              return ChoiceChip(
                label: Text('${v.name}$extra'),
                selected: sel,
                showCheckmark: false,
                selectedColor: Tide.derin,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: !v.inStock
                      ? Tide.misina
                      : (sel ? Colors.white : Tide.kaya),
                  decoration: v.inStock ? null : TextDecoration.lineThrough,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: sel ? Tide.derin : const Color(0xFFD3DEDB)),
                onSelected: !v.inStock
                    ? null
                    : (on) => setState(() {
                          if (on) {
                            _selected[o.id] = v.id;
                          } else if (!o.required) {
                            _selected.remove(o.id);
                          }
                        }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ProductDetail p) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E8E6))),
        ),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD3DEDB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Azalt',
                icon: const Icon(Icons.remove),
                onPressed: _qty > p.minimum ? () => setState(() => _qty--) : null,
              ),
              Text('$_qty',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                tooltip: 'Artır',
                icon: const Icon(Icons.add),
                onPressed: _qty < 99 ? () => setState(() => _qty++) : null,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Tide.samandira,
                  disabledBackgroundColor: const Color(0xFFD9DFDD),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: p.inStock ? () => _addToCart(p) : null,
                child: Text(p.inStock
                    ? 'Sepete ekle (${tl(_unitPrice(p) * _qty)})'
                    : 'Stokta yok'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
