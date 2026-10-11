import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const ayAdlari = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// Yönetim panelindeki aylık tablodan: hangi balık, hangi yem + ilgili ürünler
class BaitCard extends StatelessWidget {
  final int max;
  const BaitCard({super.key, this.max = 99});

  @override
  Widget build(BuildContext context) {
    final cfg = Api.config;
    if (cfg.bait.isEmpty) return const SizedBox.shrink();
    final month = cfg.month >= 1 && cfg.month <= 12 ? ayAdlari[cfg.month] : 'Bu ay';
    final rows = cfg.bait.take(max).toList();
    final ui = cfg.ui;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ui.yemCerceve, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: ui.yemBaslikZemin,
          child: Row(children: [
            Icon(Icons.set_meal, color: ui.yemBaslikYazi, size: ui.yemBaslikBoyut + 4),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$month ayı: hangi balık, hangi yem?',
                  style: TextStyle(color: ui.yemBaslikYazi, fontSize: ui.yemBaslikBoyut, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: ui.yemAyirici),
          _BaitRowView(rows[i]),
        ],
      ]),
    );
  }
}

class _BaitRowView extends StatelessWidget {
  final BaitRow r;
  const _BaitRowView(this.r);

  @override
  Widget build(BuildContext context) {
    final ui = Api.config.ui;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.fish,
                style: TextStyle(fontSize: ui.yemBalikBoyut, fontWeight: FontWeight.w800, color: ui.yemBalikYazi)),
            const SizedBox(height: 4),
            if (r.live.isNotEmpty && r.live != '-')
              _line(Icons.eco_outlined, 'Canlı yem', r.live, ui.yemMetinBoyut),
            _line(Icons.phishing, 'Sahte yem', r.lure, ui.yemMetinBoyut),
          ]),
        ),
        if (r.search.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ui.vurgu),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SearchResultsScreen(
                    query: r.search, title: '${r.fish} için ürünler', bait: true, category: r.category))),
            child: const Text('Ürünleri gör'),
          ),
      ]),
    );
  }

  Widget _line(IconData icon, String k, String v, double size) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: Tide.misina),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$k: ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: size)),
              TextSpan(text: v, style: TextStyle(fontSize: size)),
            ])),
          ),
        ]),
      );
}

/// Bir kelimeyle ürün listesi (yem önerisinden, vb.)
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String title;
  final bool bait;
  final int category;
  const SearchResultsScreen(
      {super.key, required this.query, required this.title, this.bait = false, this.category = 0});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final List<ProductCard> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final r = await Api.search(widget.query, page: _page + 1, bait: widget.bait, category: widget.category);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 500) _more();
          return false;
        },
        child: CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_items.isEmpty && !_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: MessageView(
                  icon: Icons.search_off, title: _error ?? 'Bu yem için şu an stokta ürün bulunamadı'),
            ),
          ProductGrid(_items),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: _loading ? const CircularProgressIndicator(color: Tide.zeytin) : const SizedBox.shrink()),
            ),
          ),
        ]),
      ),
    );
  }
}
