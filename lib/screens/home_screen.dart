import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../bait_card.dart';
import '../main.dart';
import '../models.dart';
import '../notices.dart';
import '../sea_card.dart';
import '../theme.dart';
import '../widgets.dart';
import 'category_screen.dart';
import 'catch_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;
  final _scroll = ScrollController();

  /// Kamp satırları: her açılışta (ve yenilemede) rastgele 2 grup, ürünler karışık
  List<HomeSection>? _campPick;
  HomeData? _campFor;

  List<HomeSection> _camp(HomeData d) {
    if (!Api.config.features.camp) return const [];
    if (identical(_campFor, d) && _campPick != null) return _campPick!;
    final rnd = math.Random();
    final groups = [...d.camp]..shuffle(rnd);
    _campPick = groups.take(2).map((g) {
      final items = [...g.items]..shuffle(rnd);
      return HomeSection(id: g.id, title: g.title, items: items.take(12).toList(), random: true);
    }).toList();
    _campFor = d;
    return _campPick!;
  }

  @override
  void initState() {
    super.initState();
    _future = Api.home();
    homeReset.addListener(_toTop);
  }

  @override
  void dispose() {
    homeReset.removeListener(_toTop);
    _scroll.dispose();
    super.dispose();
  }

  /// Keşfet'e basıldı / girişten dönüldü: en üste çık ve yenile
  void _toTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
    _refresh();
  }

  Future<void> _refresh() async {
    await Api.loadConfig();
    Notices.refresh();
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
              controller: _scroll,
              slivers: [
                const SliverToBoxAdapter(child: BrandHeader()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MenuBarDelegate(data?.categories ?? const []),
                ),
                if (Api.config.announcement.isNotEmpty)
                  SliverToBoxAdapter(child: _Announcement(Api.config.announcement)),
                const SliverToBoxAdapter(child: NoticeBanner()),
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
                  if (Api.config.features.baitCard) const SliverToBoxAdapter(child: BaitCard(max: 4)),
                  if (Api.config.features.catchList) const SliverToBoxAdapter(child: RecentCatchesStrip()),
                  for (final s in data.mixed(_camp(data)))
                    SliverToBoxAdapter(
                      child: HomeSectionBox(
                        title: s.title,
                        icon: s.random ? Icons.cabin_outlined : null,
                        onMore: () {
                          final c = data.categories.where((c) => c.id == s.id);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CategoryScreen(
                                  category: c.isNotEmpty ? c.first : Category(id: s.id, name: s.title))));
                        },
                        child: ProductCarousel(s.items),
                      ),
                    ),
                  if (data.newArrivals.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: HomeSectionBox(title: 'Yeni gelen balıkçılık ürünleri')),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ProductGrid(data.newArrivals),
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
              onTap: () => Shell.openSearch(context),
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
        const NoticeBell(),
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
    // Yükseklik her durumda sabit olmalı: kategoriler yüklenmeden (açılışta / bağlantı yokken)
    // boş kutu 0 yükseklikte kalırsa Flutter'ın yerleşim kuralı bozulur.
    final ui = Api.config.ui;
    return Container(
      height: maxExtent,
      color: ui.menuZemin,
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
                        style: TextStyle(
                            color: ui.menuYazi,
                            fontSize: ui.menuYaziBoyut,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
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

/// Ana sayfa bölümü: çerçeveli kutu + dikkat çeken (ama bağırmayan) başlık şeridi.
/// Renkler ve boyutlar yönetim panelinden (Görünüm) değiştirilebilir.
class HomeSectionBox extends StatelessWidget {
  final String title;
  /// Boşsa yalnızca başlık şeridi çizilir (altındaki ızgara kutunun dışında kalır)
  final Widget? child;
  final VoidCallback? onMore;
  final IconData? icon;
  const HomeSectionBox({super.key, required this.title, this.child, this.onMore, this.icon});

  @override
  Widget build(BuildContext context) {
    final ui = Api.config.ui;
    final r = Radius.circular(ui.bolumKose);
    return Container(
      margin: EdgeInsets.fromLTRB(12, ui.bolumAralik, 12, 0),
      decoration: BoxDecoration(
        color: ui.bolumZemin,
        borderRadius: BorderRadius.all(r),
        border: Border.all(color: ui.bolumCerceve),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: BoxDecoration(
            color: ui.bolumBaslikZemin,
            border: child == null ? null : Border(bottom: BorderSide(color: ui.bolumCerceve)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
          child: Row(children: [
            Container(
              width: 5,
              height: ui.bolumBaslikBoyut + 8,
              decoration: BoxDecoration(
                color: ui.bolumBaslikCizgi,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
            const SizedBox(width: 11),
            if (icon != null) ...[
              Icon(icon, size: ui.bolumBaslikBoyut + 2, color: ui.bolumBaslikCizgi),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: ui.bolumBaslikBoyut,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: ui.bolumBaslikYazi)),
            ),
            if (onMore != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: ui.vurgu, visualDensity: VisualDensity.compact),
                onPressed: onMore,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tümü', style: TextStyle(fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right, size: 18),
                ]),
              ),
          ]),
        ),
        if (child != null) Padding(padding: const EdgeInsets.only(top: 12, bottom: 12), child: child),
      ]),
    );
  }
}
