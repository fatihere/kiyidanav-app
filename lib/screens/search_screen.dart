import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _suggestions = [
    'LRF kamış', 'shore jig', 'spin makine', 'PE misina', 'kafa lambası', 'baby jig'
  ];

  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final List<ProductCard> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  int _token = 0; // eski isteklerin sonucu yenisini ezmesin

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(v));
  }

  Future<void> _run(String v, {bool more = false}) async {
    final q = v.trim();
    if (!more) {
      setState(() {
        _query = q;
        _items.clear();
        _page = 0;
        _hasMore = false;
        _error = null;
      });
    }
    if (q.length < 2) return;
    final token = ++_token;
    setState(() => _loading = true);
    try {
      final r = await Api.search(q, page: _page + 1);
      if (!mounted || token != _token) return;
      setState(() {
        _items.addAll(r.items);
        _page = r.page;
        _hasMore = r.hasMore;
      });
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = e.toString());
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                onSubmitted: _run,
                textInputAction: TextInputAction.search,
                maxLength: 64,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Ürün, marka veya model ara',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _ctrl.clear();
                            _run('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (_query.length < 2)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map((s) => ActionChip(
                            label: Text(s),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFD3DEDB)),
                            onPressed: () {
                              _ctrl.text = s;
                              _run(s);
                            },
                          ))
                      .toList(),
                ),
              ),
            )
          else ...[
            if (Api.demo) const SliverToBoxAdapter(child: DemoBanner()),
            if (_items.isEmpty && !_loading && _error == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.search_off,
                  title: '"$_query" için sonuç yok',
                  body: 'Daha kısa bir kelime veya marka adıyla dene.',
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ProductGrid(_items),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: Tide.derin)
                      : _error != null
                          ? Text(_error!, textAlign: TextAlign.center)
                          : _hasMore
                              ? OutlinedButton(
                                  onPressed: () => _run(_query, more: true),
                                  child: const Text('Daha fazla göster'))
                              : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
