import 'package:flutter/material.dart';

import '../api.dart';
import '../bait_card.dart';
import '../main.dart';
import '../models.dart';
import '../sea_card.dart';
import '../theme.dart';
import '../widgets.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.home();
  }

  Future<void> _refresh() async {
    await Api.loadConfig();
    setState(() => _future = Api.home());
    await _future.catchError((_) => const HomeData(categories: [], newArrivals: []));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Tide.turuncu,
        onRefresh: _refresh,
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: BrandHeader()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MenuBarDelegate(data?.categories ?? const []),
                ),
                if (Api.config.announcement.isNotEmpty)
                  SliverToBoxAdapter(child: _Announcement(Api.config.announcement)),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                const SliverToBoxAdapter(child: SeaCard()),
                if (snap.connectionState != ConnectionState.done)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: Tide.zeytin)),
                    ),
                  )
                else if (snap.hasError)
                  SliverToBoxAdapter(
                    child: MessageView(
                      icon: Icons.wifi_off,
                      title: 'Mağaza yüklenemedi',
                      body: snap.error.toString(),
                      actionLabel: 'Tekrar dene',
                      onAction: _refresh,
                    ),
                  )
                else ...[
                  _title('Kategoriler'),
                  SliverToBoxAdapter(child: _CategoryGrid(data!.categories)),
                  const SliverToBoxAdapter(child: BaitCard(max: 4)),
                  for (final s in data!.sections) ...[
                    _title(s.title, onMore: () {
                      final c = data!.categories.where((c) => c.id == s.id);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CategoryScreen(
                              category: c.isNotEmpty ? c.first : Category(id: s.id, name: s.title))));
                    }),
                    SliverToBoxAdapter(child: ProductCarousel(s.items)),
                  ],
                  if (data!.newArrivals.isNotEmpty) ...[
                    _title('Yeni gelen balıkçılık ürünleri'),
                    ProductGrid(data!.newArrivals),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(String t, {VoidCallback? onMore}) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 8, 10),
          child: Row(children: [
            Expanded(child: Text(t, style: Theme.of(context).textTheme.titleLarge)),
            if (onMore != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Tide.turuncu),
                onPressed: onMore,
                child: const Text('Tümü'),
              ),
          ]),
        ),
      );
}

/// Logo + sitenin somon renkli arama kutusu
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(children: [
        ClipOval(
          child: Image.asset('assets/brand/logo.png',
              width: 46,
              height: 46,
              errorBuilder: (_, __, ___) => Container(
                    width: 46,
                    height: 46,
                    color: Tide.zeytin,
                    alignment: Alignment.center,
                    child: const Text('KA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Tide.somon,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Shell.goTo(context, Shell.tabSearch),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Text('Aradığınız ürünü yazınız…',
                        style: TextStyle(color: Color(0xFF6B4B3E), fontSize: 13.5)),
                  ),
                  Icon(Icons.search, color: Tide.zeytinKoyu),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Sitenin zeytin yeşili üst menüsü (kaydırılabilir, ekranın üstüne yapışır)
class _MenuBarDelegate extends SliverPersistentHeaderDelegate {
  final List<Category> cats;
  _MenuBarDelegate(this.cats);

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Tide.zeytin,
      child: cats.isEmpty
          ? const SizedBox.shrink()
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: cats.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CategoryScreen(category: cats[i]))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(cats[i].name.toLocaleUpperCaseTr(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  bool shouldRebuild(_MenuBarDelegate old) => old.cats != cats;
}

extension _TrUpper on String {
  String toLocaleUpperCaseTr() => replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

class _Announcement extends StatelessWidget {
  final String text;
  const _Announcement(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Tide.altin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Tide.kaya, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Category> cats;
  const _CategoryGrid(this.cats);

  @override
  Widget build(BuildContext context) {
    if (cats.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = cats[i];
          return SizedBox(
            width: 108,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: c))),
                child: Column(children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: NetImage(c.image, fit: BoxFit.contain),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF1EFE6),
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                    child: Text(c.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
