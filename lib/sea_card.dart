import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'sea.dart';
import 'theme.dart';

/// Seçili nokta tüm uygulamada ortak (av raporu da bunu kullanır)
final selectedSpot = ValueNotifier<Spot>(spots[5]); // Kartal
const _spotKey = 'spot_v2';

Future<void> loadSelectedSpot() async {
  try {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_spotKey);
    final match = spots.where((s) => s.name == name);
    if (match.isNotEmpty) selectedSpot.value = match.first;
  } catch (_) {}
}

Future<void> saveSelectedSpot(Spot s) async {
  selectedSpot.value = s;
  try {
    (await SharedPreferences.getInstance()).setString(_spotKey, s.name);
  } catch (_) {}
}

class SeaCard extends StatefulWidget {
  const SeaCard({super.key});

  @override
  State<SeaCard> createState() => _SeaCardState();
}

class _SeaCardState extends State<SeaCard> with TickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late Side _side = selectedSpot.value.side;
  final Map<Side, List<SpotForecast>> _data = {};
  bool _loading = true;
  bool _failed = false;

  double get _threshold => Api.config.waveThreshold;

  @override
  void initState() {
    super.initState();
    _load(_side);
  }

  Future<void> _load(Side side) async {
    setState(() {
      _loading = !_data.containsKey(side);
      _failed = false;
    });
    try {
      final r = await SeaService.fetchSide(side);
      if (!mounted) return;
      setState(() {
        _data[side] = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = !_data.containsKey(side);
        _loading = false;
      });
    }
  }

  void _switchSide(Side s) {
    if (s == _side) return;
    setState(() => _side = s);
    if (selectedSpot.value.side != s) saveSelectedSpot(spotsOf(s).first);
    _load(s);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _wave.stop();
      _blink.stop();
    } else {
      if (!_wave.isAnimating) _wave.repeat();
      if (!_blink.isAnimating) _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _blink.dispose();
    super.dispose();
  }

  SpotForecast? _current(List<SpotForecast>? list) {
    if (list == null || list.isEmpty) return null;
    final m = list.where((e) => e.spot.name == selectedSpot.value.name);
    return m.isNotEmpty ? m.first : list.first;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Spot>(
      valueListenable: selectedSpot,
      builder: (context, spot, _) {
        final list = _data[_side];
        final cur = _current(list);
        final r = cur?.now;
        final wave = r == null ? 0.3 : (r.strait ? 0.3 : r.effectiveWave);
        final high = r != null && !r.strait && r.effectiveWave >= _threshold;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Yaka seçimi
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(children: [
                for (final s in Side.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _SideButton(
                        label: s == Side.anadolu ? 'Anadolu Yakası' : 'Avrupa Yakası',
                        selected: _side == s,
                        onTap: () => _switchSide(s),
                      ),
                    ),
                  ),
              ]),
            ),
            SizedBox(
              height: 190,
              child: Stack(children: [
                Positioned.fill(
                  top: null,
                  child: SizedBox(
                    height: 80,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_wave, _blink]),
                      builder: (_, __) => CustomPaint(
                        painter: _WavePainter(
                          phase: _wave.value,
                          amplitude: (wave * 14).clamp(3.0, 24.0),
                          label: r == null
                              ? null
                              : r.strait
                                  ? 'Boğaz içi · akıntıya dikkat'
                                  : r.waveM == null
                                      ? null
                                      : 'Anlık dalga ${r.waveM!.toStringAsFixed(1)} m · 6 sa. en fazla ${r.effectiveWave.toStringAsFixed(1)} m',
                          alert: high,
                          blink: _blink.value,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 70),
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : (_failed || r == null)
                          ? Row(children: [
                              const Expanded(
                                  child: Text('Deniz durumu şu an alınamadı.',
                                      style: TextStyle(color: Colors.white, fontSize: 15))),
                              TextButton(
                                onPressed: () => _load(_side),
                                style: TextButton.styleFrom(foregroundColor: Tide.turuncu),
                                child: const Text('Yenile'),
                              ),
                            ])
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.place, color: Color(0xFFBFD6D1), size: 17),
                                const SizedBox(width: 4),
                                Text(cur!.spot.name,
                                    style: const TextStyle(color: Color(0xFFBFD6D1), fontWeight: FontWeight.w700)),
                                if (high) ...[
                                  const SizedBox(width: 8),
                                  _BlinkDot(controller: _blink),
                                  const SizedBox(width: 4),
                                  const Text('Yüksek dalga',
                                      style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ]),
                              const SizedBox(height: 6),
                              Text(r.verdict,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 20, height: 1.2, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 18, runSpacing: 8, children: [
                                _stat('Rüzgâr', '${r.windKmh?.round() ?? '-'} km/s ${r.windFrom}'),
                                if (r.gustKmh != null) _stat('Hamle', '${r.gustKmh!.round()} km/s'),
                                if (r.rainDay != null && r.rainDay! >= 1) _stat('Yağış', '${r.rainDay!.round()} mm'),
                                if (r.seaC != null) _stat('Su', '${r.seaC!.round()}°'),
                                if (r.airC != null) _stat('Hava', '${r.airC!.round()}°'),
                              ]),
                            ]),
                ),
              ]),
            ),
            // Kıyı boyunca tarama: her nokta, dalga ve uyarı
            if (list != null && list.isNotEmpty)
              Container(
                color: const Color(0xFF0A2F36),
                height: 74,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = list[i];
                    final sel = f.spot.name == spot.name;
                    final hi = !f.now.strait && f.now.effectiveWave >= _threshold;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => saveSelectedSpot(f.spot),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? Tide.derinAcik : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? Tide.turuncu : const Color(0xFF2A5860)),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (hi) ...[_BlinkDot(controller: _blink, size: 7), const SizedBox(width: 4)],
                            Text(f.spot.name,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 2),
                          Text(
                            f.now.strait
                                ? 'Boğaz'
                                : f.now.waveM == null
                                    ? '—'
                                    : f.now.effectiveWave > (f.now.waveM ?? 0) + 0.05
                                        ? '${f.now.waveM!.toStringAsFixed(1)}→${f.now.effectiveWave.toStringAsFixed(1)} m'
                                        : '${f.now.waveM!.toStringAsFixed(1)} m',
                            style: TextStyle(
                                color: hi ? const Color(0xFFFF8A80) : const Color(0xFF9FC4BD),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8FB0AA), fontSize: 11.5)),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      );
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SideButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Tide.turuncu : const Color(0xFF16474F),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFBFD6D1),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _BlinkDot extends StatelessWidget {
  final AnimationController controller;
  final double size;
  const _BlinkDot({required this.controller, this.size = 9});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(const Color(0xFFFF1744), const Color(0x33FF1744), controller.value),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF1744).withAlpha((120 * (1 - controller.value)).round()),
                blurRadius: 6,
                spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final String? label;
  final bool alert;
  final double blink;
  _WavePainter({required this.phase, required this.amplitude, this.label, this.alert = false, this.blink = 0});

  double _y(Size size, double x, double shift, double ampScale, double baseline) {
    final t = (x / size.width) * 2 * math.pi * 1.5 + (phase + shift) * 2 * math.pi;
    return baseline + math.sin(t) * amplitude * ampScale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    void layer(Color color, double shift, double ampScale, double baseline) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        path.lineTo(x, _y(size, x, shift, ampScale, baseline));
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    layer(const Color(0xFF1C5A63), 0.0, 1.0, size.height * 0.50);
    layer(const Color(0xFF2A7078), 0.35, 0.7, size.height * 0.70);

    // Şamandıra
    final bx = size.width * 0.74;
    final by = _y(size, bx, 0.35, 0.7, size.height * 0.70);
    canvas.drawCircle(Offset(bx, by - 5), 7, Paint()..color = Tide.turuncu);
    canvas.drawRect(Rect.fromLTWH(bx - 1, by - 19, 2, 8), Paint()..color = Colors.white);

    // Yüksek dalgada şamandıra tepesinde yanıp sönen kırmızı ışık
    if (alert) {
      final a = (255 * (1 - blink)).round();
      canvas.drawCircle(Offset(bx, by - 22), 4.5, Paint()..color = Color.fromARGB(a, 255, 23, 68));
      canvas.drawCircle(Offset(bx, by - 22), 9,
          Paint()..color = Color.fromARGB((a * 0.35).round(), 255, 23, 68));
    }

    // Etiket: "Anlık dalga 0.4 m"
    final l = label;
    if (l != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: l,
          style: TextStyle(
              fontFamily: Tide.font,
              color: alert ? const Color(0xFFFFCDD2) : Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(40.0, size.width - 24));
      final maxX = math.max(6.0, size.width - tp.width - 6);
      final maxY = math.max(2.0, size.height - tp.height - 2);
      final px = (bx - tp.width - 18).clamp(6.0, maxX);
      final py = (by - 30).clamp(2.0, maxY);
      final bg = RRect.fromRectAndRadius(
          Rect.fromLTWH(px - 6, py - 3, tp.width + 12, tp.height + 6), const Radius.circular(8));
      canvas.drawRRect(bg, Paint()..color = const Color(0xAA0A2F36));
      tp.paint(canvas, Offset(px, py));
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
