import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bait_card.dart' show SearchResultsScreen;
import '../config.dart';
import '../freshwater.dart';
import '../mera.dart' show MemberGate;
import '../overlays.dart' show CloseX;
import '../theme.dart';

// Harita renkleri
const _deniz = Color(0xFFDDEBEE);
const _kara = Color(0xFFF1EEE4);
const _ilSinir = Color(0xFFD2CBB5);
const _gol = Color(0xFF9CCBD8);
const _dogalRenk = Color(0xFF1B7A9A);
const _barajRenk = Tide.turuncu;
const _yasakRenk = Color(0xFF9A988A);

Color _placeColor(FwPlace p) => p.noFishing ? _yasakRenk : (p.isDam ? _barajRenk : _dogalRenk);

Future<void> _openDirections(FwPlace p) => launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '${p.lat},${p.lon}'}),
      mode: LaunchMode.externalApplication,
    );

void _openGear(BuildContext context, FwGear g) => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SearchResultsScreen(query: g.query, title: g.name)));

// =====================================================================
// Mera Bilgisi sekmesindeki giriş kartı
// =====================================================================
class FreshwaterEntry extends StatelessWidget {
  const FreshwaterEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: Tide.derin,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FreshwaterScreen())),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.water, color: Color(0xFF8FD3E3), size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tatlı Su Meraları ve Avlanma Yöntemleri',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Türkiye göl ve barajları — harita, balıklar, yöntem ve ekipman',
                      style: TextStyle(color: Color(0xFFCFE3E6), fontSize: 12.5)),
                ]),
              ),
              Icon(Icons.chevron_right, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Ana ekran: harita + il bazında liste
// =====================================================================
class FreshwaterScreen extends StatefulWidget {
  const FreshwaterScreen({super.key});

  @override
  State<FreshwaterScreen> createState() => _FreshwaterScreenState();
}

enum _Kind { all, lake, dam }

class _FreshwaterScreenState extends State<FreshwaterScreen> {
  late final Future<(FwData, FwMapShapes)> _future =
      Future.wait([FreshwaterService.load(), FreshwaterService.loadMap()]).then((r) => (r[0] as FwData, r[1] as FwMapShapes));
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _q = '';
  _Kind _kind = _Kind.all;
  String? _selected;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FwPlace> _filter(FwData d) {
    final q = trLower(_q.trim());
    return d.places.where((p) {
      if (_kind == _Kind.lake && p.isDam) return false;
      if (_kind == _Kind.dam && !p.isDam) return false;
      if (q.isEmpty) return true;
      final t = p.searchText(d.fish);
      return q.split(RegExp(r'\s+')).every(t.contains);
    }).toList();
  }

  void _showSummary(FwData d, FwPlace p) {
    setState(() => _selected = p.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PlaceSummary(data: d, place: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tatlı Su Meraları')),
      body: MemberGate(
        title: 'Tatlı su meraları üyelere özel',
        message: 'Ücretsiz üye ol; Türkiye\'nin göl ve barajlarını haritada gör, çıkan balıkları, '
            'avlanma yöntemlerini ve önerilen ekipmanları öğren.',
        child: FutureBuilder<(FwData, FwMapShapes)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tide.zeytin));
            }
            if (snap.hasError || snap.data == null) {
              return const Center(child: Text('Tatlı su verileri açılamadı.'));
            }
            final (data, shapes) = snap.data!;
            final list = _filter(data);
            return Column(children: [
              _FwMap(
                shapes: shapes,
                places: list,
                selected: _selected,
                onTap: (p) => _showSummary(data, p),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Göl, baraj, il, ilçe ya da balık ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _search.clear();
                              _q = '';
                            }),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0DCCF))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0DCCF))),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  children: [
                    for (final k in _Kind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (k) { _Kind.all => 'Tümü', _Kind.lake => 'Göller', _Kind.dam => 'Barajlar' }),
                          selected: _kind == k,
                          selectedColor: Tide.somon,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const _Legend(color: _dogalRenk, text: 'Göl'),
                    const _Legend(color: _barajRenk, text: 'Baraj'),
                    const _Legend(color: _yasakRenk, text: 'Av yasak'),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Aramaya uyan göl ya da baraj yok.'))
                    : _PlaceList(
                        data: data,
                        places: list,
                        controller: _scroll,
                        note: data.note,
                        mapSource: shapes.source,
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A5E))),
        ]),
      );
}

// =====================================================================
// Harita: il sınırları + göller + tıklanabilir noktalar (yakınlaştırılabilir)
// =====================================================================
class _FwMap extends StatefulWidget {
  final FwMapShapes shapes;
  final List<FwPlace> places;
  final String? selected;
  final ValueChanged<FwPlace> onTap;
  const _FwMap({required this.shapes, required this.places, required this.selected, required this.onTap});

  @override
  State<_FwMap> createState() => _FwMapState();
}

class _FwMapState extends State<_FwMap> {
  final _tc = TransformationController();
  final _geo = _MapGeometry();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  void _zoom(double f, Size size) {
    final s = (_scale * f).clamp(1.0, 10.0);
    if (s <= 1.0) {
      _tc.value = Matrix4.identity();
      return;
    }
    // Ekranın ortasını sabit tutarak yakınlaştır
    final center = _tc.toScene(Offset(size.width / 2, size.height / 2));
    _tc.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, size.width / 2 - s * center.dx)
      ..setEntry(1, 3, size.height / 2 - s * center.dy);
  }

  void _handleTap(Offset local, Size size) {
    final r = 22 / _scale;
    FwPlace? best;
    var bestD = double.infinity;
    for (final p in widget.places) {
      final d = (FwProjection.project(p.lon, p.lat, size) - local).distance;
      if (d < r && d < bestD) {
        best = p;
        bestD = d;
      }
    }
    if (best != null) widget.onTap(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final size = Size(w, w * FwProjection.aspect);
      return Container(
        color: _deniz,
        child: Stack(children: [
          SizedBox(
            width: size.width,
            height: size.height,
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _handleTap(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _MapPainter(
                      geo: _geo,
                      shapes: widget.shapes,
                      places: widget.places,
                      selected: widget.selected,
                      tc: _tc,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Column(children: [
              _MapButton(icon: Icons.add, onTap: () => _zoom(1.8, size)),
              const SizedBox(height: 4),
              _MapButton(icon: Icons.remove, onTap: () => _zoom(1 / 1.8, size)),
              const SizedBox(height: 4),
              _MapButton(icon: Icons.zoom_out_map, onTap: () => _tc.value = Matrix4.identity()),
            ]),
          ),
          const Positioned(
            left: 8,
            bottom: 4,
            child: Text('Noktaya dokun · iki parmakla yakınlaştır',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF5E6B6E))),
          ),
        ]),
      );
    });
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 18, color: Tide.zeytinKoyu)),
        ),
      );
}

/// Yolların (Path) ekran boyutuna göre bir kez hesaplanıp saklanması
class _MapGeometry {
  Size? _size;
  FwMapShapes? _shapes;
  final provinces = <Path>[];
  final water = <Path>[];

  void ensure(FwMapShapes shapes, Size size) {
    if (_size == size && identical(_shapes, shapes)) return;
    _size = size;
    _shapes = shapes;
    provinces.clear();
    water.clear();
    Path build(List<double> r) {
      final path = Path();
      for (var i = 0; i + 1 < r.length; i += 2) {
        final o = FwProjection.project(r[i], r[i + 1], size);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      return path..close();
    }

    for (final p in shapes.provinces) {
      final path = Path();
      for (final r in p.value) {
        path.addPath(build(r), Offset.zero);
      }
      provinces.add(path);
    }
    for (final r in shapes.water) {
      water.add(build(r));
    }
  }
}

class _MapPainter extends CustomPainter {
  final _MapGeometry geo;
  final FwMapShapes shapes;
  final List<FwPlace> places;
  final String? selected;
  final TransformationController tc;

  _MapPainter({required this.geo, required this.shapes, required this.places, required this.selected, required this.tc})
      : super(repaint: tc);

  @override
  void paint(Canvas canvas, Size size) {
    geo.ensure(shapes, size);
    final scale = tc.value.getMaxScaleOnAxis();

    final land = Paint()..color = _kara;
    final border = Paint()
      ..color = _ilSinir
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7 / scale;
    for (final p in geo.provinces) {
      canvas.drawPath(p, land);
    }
    for (final p in geo.provinces) {
      canvas.drawPath(p, border);
    }
    final water = Paint()..color = _gol;
    for (final p in geo.water) {
      canvas.drawPath(p, water);
    }

    final r = 4.6 / scale;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / scale;
    FwPlace? sel;
    for (final p in places) {
      if (p.id == selected) {
        sel = p;
        continue;
      }
      final o = FwProjection.project(p.lon, p.lat, size);
      canvas.drawCircle(o, r, Paint()..color = _placeColor(p));
      canvas.drawCircle(o, r, ring);
    }

    // Yakınlaşınca adlar
    if (scale >= 2.6) {
      for (final p in places) {
        final o = FwProjection.project(p.lon, p.lat, size);
        final tp = TextPainter(
          text: TextSpan(
            text: p.name,
            style: TextStyle(
              fontSize: 10.5 / scale,
              color: Tide.kaya,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.white, blurRadius: 3 / scale)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o + Offset(r + 2 / scale, -tp.height / 2));
      }
    }

    if (sel != null) {
      final o = FwProjection.project(sel.lon, sel.lat, size);
      canvas.drawCircle(o, r * 2.4, Paint()..color = _placeColor(sel).withAlpha(70));
      canvas.drawCircle(o, r * 1.5, Paint()..color = _placeColor(sel));
      canvas.drawCircle(o, r * 1.5, ring..strokeWidth = 2 / scale);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.places != places || old.selected != selected || old.shapes != shapes;
}

// =====================================================================
// İl bazında liste
// =====================================================================
class _PlaceList extends StatelessWidget {
  final FwData data;
  final List<FwPlace> places;
  final ScrollController controller;
  final String note;
  final String mapSource;
  const _PlaceList(
      {required this.data, required this.places, required this.controller, required this.note, required this.mapSource});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    String? il;
    for (final p in places) {
      if (p.province != il) {
        il = p.province;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(trUpper(il),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Tide.zeytin)),
        ));
      }
      rows.add(_PlaceTile(data: data, place: p));
    }
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Text('${places.length} göl ve baraj. $note',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF77766A), height: 1.4)),
    ));
    return ListView(controller: controller, padding: EdgeInsets.zero, children: rows);
  }
}

class _PlaceTile extends StatelessWidget {
  final FwData data;
  final FwPlace place;
  const _PlaceTile({required this.data, required this.place});

  @override
  Widget build(BuildContext context) {
    final p = place;
    final fish = p.fish.map((k) => data.fish[k]?.name ?? k).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => FreshwaterDetailScreen(data: data, place: p))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E2D6)),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _placeColor(p).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Icon(p.isDam ? Icons.water_damage_outlined : Icons.water, color: _placeColor(p)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text([p.district, if (p.area.isNotEmpty) p.area].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(p.noFishing ? 'Avlanma yasak' : fish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: p.noFishing ? Tide.mercan : const Color(0xFF6B6A5E))),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Tide.misina),
            ]),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Haritada dokununca açılan özet
// =====================================================================
class _PlaceSummary extends StatelessWidget {
  final FwData data;
  final FwPlace place;
  const _PlaceSummary({required this.data, required this.place});

  @override
  Widget build(BuildContext context) {
    final p = place;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${p.type} · ${p.province} / ${p.district}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B6A5E))),
              ]),
            ),
            CloseX(onTap: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 12),
          _FactGrid(place: p),
          if (p.warning.isNotEmpty) ...[const SizedBox(height: 10), _WarningBox(p.warning, strong: p.noFishing)],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in p.fish) _FishChip(data.fish[k]?.name ?? k),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size(0, 46)),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => FreshwaterDetailScreen(data: data, place: p)));
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Detaylar ve ekipman'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: Tide.zeytinKoyu),
              onPressed: () => _openDirections(p),
              icon: const Icon(Icons.directions_car),
              label: const Text('Yol tarifi'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FactGrid extends StatelessWidget {
  final FwPlace place;
  final bool dark;
  const _FactGrid({required this.place, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String, String)>[
      (Icons.straighten, 'Büyüklük', place.area.isEmpty ? 'Bilgi yok' : place.area),
      (Icons.vertical_align_bottom, 'Derinlik', place.depth.isEmpty ? 'Bilgi yok' : place.depth),
      (Icons.forest_outlined, 'Çevre', place.surroundings.isEmpty ? 'Bilgi yok' : place.surroundings),
      (Icons.cabin_outlined, 'Kamp / konaklama', place.camp.isEmpty ? 'Bilgi yok' : _short(place.camp)),
    ];
    final fg = dark ? Colors.white : Tide.kaya;
    final sub = dark ? const Color(0xFFBFD6DA) : const Color(0xFF77766A);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in facts)
          Container(
            width: w,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dark ? const Color(0x22FFFFFF) : const Color(0xFFF6F4EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(f.$1, size: 18, color: dark ? const Color(0xFF8FD3E3) : Tide.turuncu),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$2, style: TextStyle(fontSize: 11.5, color: sub)),
                  const SizedBox(height: 2),
                  Text(f.$3, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg, height: 1.3)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }

  /// Kamp bilgisinin ilk cümlesi (özet kutusu için)
  static String _short(String s) {
    final i = s.indexOf(';');
    return i > 0 ? s.substring(0, i) : s;
  }
}

class _WarningBox extends StatelessWidget {
  final String text;
  final bool strong;
  const _WarningBox(this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: strong ? const Color(0xFFFDECEA) : const Color(0xFFFFF5DD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strong ? const Color(0xFFF2B8B3) : const Color(0xFFF0D79A)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(strong ? Icons.block : Icons.warning_amber_rounded,
              size: 18, color: strong ? Tide.mercan : const Color(0xFFB7791F)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}

class _FishChip extends StatelessWidget {
  final String text;
  const _FishChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFE3F1F4), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.set_meal, size: 14, color: _dogalRenk),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Tide.derin)),
        ]),
      );
}

// =====================================================================
// Detay sayfası
// =====================================================================
class FreshwaterDetailScreen extends StatelessWidget {
  final FwData data;
  final FwPlace place;
  const FreshwaterDetailScreen({super.key, required this.data, required this.place});

  @override
  Widget build(BuildContext context) {
    final p = place;
    final gear = data.gearFor(p);
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p.isDam ? Icons.water_damage_outlined : Icons.water, color: const Color(0xFF8FD3E3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${p.type} · ${p.province}',
                    style: const TextStyle(color: Color(0xFFCFE3E6), fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('İlçe: ${p.district}', style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            const SizedBox(height: 12),
            _FactGrid(place: p, dark: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size(0, 44)),
                  onPressed: () => _openDirections(p),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Yol tarifi al'),
                ),
              ),
            ]),
          ]),
        ),
        if (p.warning.isNotEmpty) ...[const SizedBox(height: 12), _WarningBox(p.warning, strong: p.noFishing)],
        _Section(icon: Icons.forest_outlined, title: 'Çevre ve coğrafya', text: p.surroundingsNote),
        _Section(icon: Icons.directions_car_outlined, title: 'Araçla ulaşım', text: p.road),
        _Section(icon: Icons.cabin_outlined, title: 'Kamp ve konaklama', text: p.camp),
        if (p.tip.isNotEmpty) _Section(icon: Icons.tips_and_updates_outlined, title: 'Mera notu', text: p.tip),
        if (!p.noFishing && gear.isNotEmpty) ...[
          const _Heading(icon: Icons.shopping_bag_outlined, text: 'Önerilen ekipman (kiyidanav.com)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in gear)
              ActionChip(
                avatar: const Icon(Icons.arrow_forward, size: 16, color: Tide.turuncu),
                label: Text(g.name),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFF2C6AE)),
                onPressed: () => _openGear(context, g),
              ),
          ]),
        ],
        _Heading(icon: Icons.set_meal, text: p.noFishing ? 'Gölde yaşayan balıklar' : 'Çıkan balıklar ve avlanma yöntemleri'),
        for (final k in p.fish)
          if (data.fish[k] != null) _FishCard(fish: data.fish[k]!, showGear: !p.noFishing) else _FishChip(k),
        const SizedBox(height: 18),
        Text(data.note, style: const TextStyle(fontSize: 11.5, color: Color(0xFF77766A), height: 1.4)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Tide.zeytinKoyu, padding: EdgeInsets.zero),
            onPressed: () => launchUrl(
              Uri.https('wa.me', '/${AppConfig.whatsapp}',
                  {'text': 'Tatlı su meraları — ${p.name} (${p.province}) için düzeltme/ek bilgi: '}),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.edit_note),
            label: const Text('Hata ya da eksik bilgi bildir'),
          ),
        ),
      ]),
    );
  }
}

class _Heading extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Heading({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
        child: Row(children: [
          Icon(icon, size: 20, color: Tide.turuncu),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
      );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Section({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Heading(icon: icon, text: title),
      Text(text, style: const TextStyle(fontSize: 14.5, height: 1.5)),
    ]);
  }
}

class _FishCard extends StatelessWidget {
  final FwFish fish;
  final bool showGear;
  const _FishCard({required this.fish, this.showGear = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFE3F1F4), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.set_meal, color: _dogalRenk),
          ),
          title: Text(fish.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          subtitle: fish.bait.isEmpty
              ? null
              : Text('Yem: ${fish.bait}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          children: [
            if (fish.season.isNotEmpty)
              _kv(Icons.event, 'Ne zaman', fish.season),
            if (fish.bait.isNotEmpty) _kv(Icons.eco_outlined, 'Yem', fish.bait),
            const SizedBox(height: 6),
            for (var i = 0; i < fish.methods.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Tide.zeytin, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${fish.methods[i].title}\n', style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: fish.methods[i].text),
                    ]), style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ]),
              ),
            if (showGear && fish.gear.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final g in fish.gear)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Tide.turuncu,
                        side: const BorderSide(color: Color(0xFFF2C6AE)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openGear(context, g),
                      child: Text(g.name),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Tide.misina),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: v),
            ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ]),
      );
}
