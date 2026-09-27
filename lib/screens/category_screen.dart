import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class CategoryScreen extends StatefulWidget {
  final Category category;
  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  static const _sorts = {
    'new': 'En yeniler',
    'price_asc': 'Fiyat: düşükten yükseğe',
    'price_desc': 'Fiyat: yüksekten düşüğe',
    'name': 'Ada göre (A-Z)',
  };

  final _scroll = ScrollController();
  final List<ProductCard> _items = [];
  List<Category> _subs = [];
  String _sort = 'new';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });
    if (widget.category.hasChildren) {
      Api.categories(widget.category.id).then((s) {
        if (mounted) setState(() => _subs = s);
      }).catchError((_) {});
    }
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r =
          await Api.products(widget.category.id, page: _page + 1, sort: _sort);
      if (!mounted) return;
      setState(() {
        _page = r.page;
        _hasMore = r.hasMore;
        _items.addAll(r.items);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeSort(String s) {
    setState(() {
      _sort = s;
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: _changeSort,
            itemBuilder: (_) => _sorts.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          if (Api.demo) const SliverToBoxAdapter(child: DemoBanner()),
          if (_subs.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _subs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text(_subs[i].name),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD3DEDB)),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                CategoryScreen(category: _subs[i]))),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_items.isEmpty && !_loading && _error == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: MessageView(
                icon: Icons.inventory_2_outlined,
                title: 'Bu kategoride şu an ürün yok',
                body: 'Yeni ürünler eklendikçe burada görünecek.',
              ),
            ),
          ProductGrid(_items),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _error != null
                    ? Column(children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                            onPressed: _loadMore,
                            child: const Text('Tekrar dene')),
                      ])
                    : _loading
                        ? const CircularProgressIndicator(color: Tide.derin)
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
