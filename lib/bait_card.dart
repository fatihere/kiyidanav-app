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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Tide.zeytin,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.set_meal, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$month ayı: hangi balık, hangi yem?',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.fish, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Tide.zeytinKoyu)),
            const SizedBox(height: 4),
            if (r.live.isNotEmpty && r.live != '-')
              _line(Icons.eco_outlined, 'Canlı yem', r.live),
            _line(Icons.phishing, 'Sahte yem', r.lure),
          ]),
        ),
        if (r.search.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Tide.turuncu),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SearchResultsScreen(query: r.search, title: '${r.fish} için ürünler'))),
            child: const Text('Ürünleri gör'),
          ),
      ]),
    );
  }

  Widget _line(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: Tide.misina),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              TextSpan(text: v, style: const TextStyle(fontSize: 13)),
            ])),
          ),
        ]),
      );
}

/// Bir kelimeyle ürün listesi (yem önerisinden, vb.)
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String title;
  const SearchResultsScreen({super.key, required this.query, required this.title});

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
      final r = await Api.search(widget.query, page: _page + 1);
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
