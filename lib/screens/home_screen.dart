import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../sea.dart';
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
    setState(() => _future = Api.home());
    await _future.catchError((_) => const HomeData(categories: [], newArrivals: []));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Tide.samandira,
        onRefresh: _refresh,
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snap) {
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                const SliverToBoxAdapter(child: SeaCard()),
                if (snap.connectionState != ConnectionState.done)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(color: Tide.derin)),
                  )
                else if (snap.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MessageView(
                      icon: Icons.wifi_off,
                      title: 'Mağaza yüklenemedi',
                      body: snap.error.toString(),
                      actionLabel: 'Tekrar dene',
                      onAction: _refresh,
                    ),
                  )
                else ...[
                  if (Api.demo) const SliverToBoxAdapter(child: DemoBanner()),
                  _sectionTitle('Kategoriler'),
                  SliverToBoxAdapter(
                      child: _CategoryStrip(snap.data!.categories)),
                  _sectionTitle('Yeni gelenler'),
                  ProductGrid(snap.data!.newArrivals),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(t, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Tide.derin, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
                color: Tide.samandira, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        const Text('KıyıdanAv',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Tide.derin)),
      ]),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final List<Category> cats;
  const _CategoryStrip(this.cats);

  @override
  Widget build(BuildContext context) {
    if (cats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Henüz kategori yok.'),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = cats[i];
          return SizedBox(
            width: 104,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CategoryScreen(category: c))),
                child: Column(children: [
                  Expanded(
                      child: SizedBox(
                          width: double.infinity, child: NetImage(c.image))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                    child: Text(c.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600)),
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

// ---------------------------------------------------------------------------
// Deniz durumu — uygulamanın imza anı. Dalga animasyonunun yüksekliği
// seçilen kıyıdaki gerçek dalga yüksekliğine göre değişir.
// ---------------------------------------------------------------------------

class SeaCard extends StatefulWidget {
  const SeaCard({super.key});

  @override
  State<SeaCard> createState() => _SeaCardState();
}

class _SeaCardState extends State<SeaCard> with SingleTickerProviderStateMixin {
  static const _spotKey = 'spot_v1';
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  int _spot = 0;
  SeaReport? _report;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _spot = (p.getInt(_spotKey) ?? 0).clamp(0, spots.length - 1);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await SeaService.fetch(spots[_spot]);
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _pickSpot() async {
    final i = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Hangi kıyıya bakalım?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (var k = 0; k < spots.length; k++)
              ListTile(
                title: Text(spots[k].name),
                trailing: k == _spot
                    ? const Icon(Icons.check, color: Tide.samandira)
                    : null,
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (i == null || i == _spot) return;
    _spot = i;
    try {
      (await SharedPreferences.getInstance()).setInt(_spotKey, i);
    } catch (_) {}
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hareket azaltma ayarı açıksa dalga durur
    if (MediaQuery.of(context).disableAnimations) {
      _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final wave = r?.waveM ?? 0.3;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Tide.derin,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          top: null,
          child: SizedBox(
            height: 70,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(
                painter: _WavePainter(
                    phase: _anim.value, amplitude: (wave * 16).clamp(3.0, 22.0)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _pickSpot,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.place_outlined,
                        color: Color(0xFFBFD6D1), size: 18),
                    const SizedBox(width: 4),
                    Text(spots[_spot].name,
                        style: const TextStyle(
                            color: Color(0xFFBFD6D1),
                            fontWeight: FontWeight.w600)),
                    const Icon(Icons.expand_more,
                        color: Color(0xFFBFD6D1), size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              else if (_failed || r == null)
                Row(children: [
                  const Expanded(
                    child: Text('Deniz durumu şu an alınamadı.',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: _load,
                    style: TextButton.styleFrom(foregroundColor: Tide.samandira),
                    child: const Text('Yenile'),
                  ),
                ])
              else ...[
                Text(r.verdict,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 14),
                Wrap(spacing: 22, runSpacing: 10, children: [
                  _stat('Rüzgâr',
                      '${r.windKmh?.round() ?? '-'} km/s${r.windFrom.isEmpty ? '' : ' ${r.windFrom}'}'),
                  if (r.gustKmh != null) _stat('Hamle', '${r.gustKmh!.round()} km/s'),
                  if (r.waveM != null) _stat('Dalga', '${r.waveM!.toStringAsFixed(1)} m'),
                  if (r.seaC != null) _stat('Su', '${r.seaC!.round()}°'),
                  if (r.airC != null) _stat('Hava', '${r.airC!.round()}°'),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF8FB0AA), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _WavePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  _WavePainter({required this.phase, required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    void layer(Color color, double shift, double ampScale, double baseline) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final t = (x / size.width) * 2 * math.pi * 1.5 +
            (phase + shift) * 2 * math.pi;
        final y = baseline + math.sin(t) * amplitude * ampScale;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    layer(const Color(0xFF1C5A63), 0.0, 1.0, size.height * 0.45);
    layer(const Color(0xFF2A7078), 0.35, 0.7, size.height * 0.65);
    // Şamandıra: öndeki dalganın üstünde süzülür
    final bx = size.width * 0.78;
    final bt = (bx / size.width) * 2 * math.pi * 1.5 + (phase + 0.35) * 2 * math.pi;
    final by = size.height * 0.65 + math.sin(bt) * amplitude * 0.7;
    canvas.drawCircle(Offset(bx, by - 5), 6, Paint()..color = Tide.samandira);
    canvas.drawRect(Rect.fromLTWH(bx - 1, by - 17, 2, 7),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.amplitude != amplitude;
}
