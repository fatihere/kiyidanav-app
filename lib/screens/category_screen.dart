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
  // Filtre (sitedeki gibi: marka, renk, fiyat, stok)
  KategoriFiltre? _secenek;
  final Set<int> _marka = {};
  final Set<int> _renk = {};
  RangeValues? _fiyat;
  bool _stok = false;

  int get _filtreSayisi => _marka.length + _renk.length + (_fiyat != null ? 1 : 0) + (_stok ? 1 : 0);

  Map<String, String> get _filtre => {
        if (_marka.isNotEmpty) 'marka': _marka.join(','),
        if (_renk.isNotEmpty) 'renk': _renk.join(','),
        if (_fiyat != null) 'min': '${_fiyat!.start.round()}',
        if (_fiyat != null) 'max': '${_fiyat!.end.round()}',
        if (_stok) 'stok': '1',
      };

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
          await Api.products(widget.category.id, page: _page + 1, sort: _sort, filtre: _filtre);
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

  void _yeniden() {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    _loadMore();
  }

  Future<void> _filtreAc() async {
    if (_secenek == null) {
      try {
        _secenek = await Api.filtreler(widget.category.id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
    }
    if (!mounted) return;
    final f = _secenek!;
    final marka = {..._marka}, renk = {..._renk};
    var stok = _stok;
    final aralikVar = f.fiyatMax > f.fiyatMin;
    var fiyat = _fiyat ?? RangeValues(f.fiyatMin.toDouble(), f.fiyatMax.toDouble());
    final uygula = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (ctx, kaydir) => ListView(controller: kaydir, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Row(children: [
              const Expanded(child: Text('Filtrele', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () => ss(() {
                  marka.clear();
                  renk.clear();
                  stok = false;
                  fiyat = RangeValues(f.fiyatMin.toDouble(), f.fiyatMax.toDouble());
                }),
                child: const Text('Temizle'),
              ),
            ]),
            if (f.altlar.isNotEmpty) ...[
              const _Baslik('Kategori'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in f.altlar)
                  ActionChip(
                    label: Text(c.name),
                    onPressed: () {
                      Navigator.of(ctx).pop(false);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: c)));
                    },
                  ),
              ]),
            ],
            if (f.markalar.isNotEmpty) ...[
              const _Baslik('Marka'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in f.markalar)
                  FilterChip(
                    label: Text('${m.ad} (${m.n})'),
                    selected: marka.contains(m.id),
                    selectedColor: Tide.somon,
                    onSelected: (v) => ss(() => v ? marka.add(m.id) : marka.remove(m.id)),
                  ),
              ]),
            ],
            if (f.renkler.isNotEmpty) ...[
              const _Baslik('Renk'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in f.renkler)
                  FilterChip(
                    label: Text('${m.ad} (${m.n})'),
                    selected: renk.contains(m.id),
                    selectedColor: Tide.somon,
                    onSelected: (v) => ss(() => v ? renk.add(m.id) : renk.remove(m.id)),
                  ),
              ]),
            ],
            if (aralikVar) ...[
              _Baslik('Fiyat: ${fiyat.start.round()} – ${fiyat.end.round()} TL'),
              RangeSlider(
                values: fiyat,
                min: f.fiyatMin.toDouble(),
                max: f.fiyatMax.toDouble(),
                divisions: 50,
                activeColor: Tide.turuncu,
                onChanged: (v) => ss(() => fiyat = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sadece stokta olanlar', style: TextStyle(fontWeight: FontWeight.w700)),
              value: stok,
              onChanged: (v) => ss(() => stok = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sonuçları göster'),
            ),
          ]),
        ),
      ),
    );
    if (uygula != true) return;
    setState(() {
      _marka
        ..clear()
        ..addAll(marka);
      _renk
        ..clear()
        ..addAll(renk);
      _stok = stok;
      final tam = !aralikVar || (fiyat.start <= f.fiyatMin && fiyat.end >= f.fiyatMax);
      _fiyat = tam ? null : fiyat;
    });
    _yeniden();
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
          if (Api.config.features.kategoriFiltre)
            IconButton(
              tooltip: 'Filtrele',
              onPressed: _filtreAc,
              icon: Badge(
                isLabelVisible: _filtreSayisi > 0,
                label: Text('$_filtreSayisi'),
                backgroundColor: Tide.turuncu,
                child: const Icon(Icons.tune),
              ),
            ),
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
          if (_filtreSayisi > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(children: [
                  Expanded(child: Text('$_filtreSayisi filtre uygulandı', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _marka.clear();
                        _renk.clear();
                        _fiyat = null;
                        _stok = false;
                      });
                      _yeniden();
                    },
                    child: const Text('Temizle'),
                  ),
                ]),
              ),
            ),
          if (_items.isEmpty && !_loading && _error == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: MessageView(
                icon: Icons.inventory_2_outlined,
                title: _filtreSayisi > 0 ? 'Bu filtreyle ürün yok' : 'Bu kategoride şu an ürün yok',
                body: _filtreSayisi > 0 ? 'Filtreyi gevşetip tekrar dene.' : 'Yeni ürünler eklendikçe burada görünecek.',
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


class _Baslik extends StatelessWidget {
  final String t;
  const _Baslik(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
      );
}
