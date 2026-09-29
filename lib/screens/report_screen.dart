import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bait_card.dart';
import '../sea.dart';
import '../sea_card.dart';
import '../share.dart';
import '../solunar.dart';
import '../theme.dart';

const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

String _tarih(DateTime d) => '${d.day} ${ayAdlari[d.month]} ${d.year}';
String _saat(DateTime? d) =>
    d == null ? '—' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _shotKey = GlobalKey();
  Future<SpotForecast>? _future;
  String? _forSpot;
  bool _sharing = false;

  void _ensure(Spot s) {
    if (_forSpot != s.name) {
      _forSpot = s.name;
      _future = SeaService.fetchWeek(s);
    }
  }

  Future<void> _share(SpotForecast f, int score) async {
    setState(() => _sharing = true);
    try {
      await Sharer.widgetImage(_shotKey,
          text: '${f.spot.name} günlük av raporu: av verimliliği %$score, '
              '${Moon.phaseName(DateTime.now())}. KıyıdanAv uygulamasıyla hazırlandı 🎣 kiyidanav.com');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rapor görseli hazırlanamadı.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Spot>(
      valueListenable: selectedSpot,
      builder: (context, spot, _) {
        _ensure(spot);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Günlük Av Raporu'),
            actions: [
              PopupMenuButton<Spot>(
                tooltip: 'Kıyı seç',
                icon: const Icon(Icons.place_outlined),
                onSelected: saveSelectedSpot,
                itemBuilder: (_) => [
                  const PopupMenuItem(enabled: false, child: Text('Anadolu Yakası')),
                  for (final s in spotsOf(Side.anadolu)) PopupMenuItem(value: s, child: Text('   ${s.name}')),
                  const PopupMenuItem(enabled: false, child: Text('Avrupa Yakası')),
                  for (final s in spotsOf(Side.avrupa)) PopupMenuItem(value: s, child: Text('   ${s.name}')),
                ],
              ),
            ],
          ),
          body: FutureBuilder<SpotForecast>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Tide.zeytin));
              }
              if (snap.hasError || !snap.hasData) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _forSpot = null),
                    child: const Text('Rapor alınamadı — tekrar dene'),
                  ),
                );
              }
              final f = snap.data!;
              final now = DateTime.now();
              final today = f.days.isNotEmpty ? f.days.first : null;
              final score = FishingScore.compute(now,
                  windKmh: f.now.effectiveWind, waveM: f.now.effectiveWave, pressureTrend: f.pressureTrend, rainMm: f.now.rainDay);
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  RepaintBoundary(
                    key: _shotKey,
                    child: _ReportCard(f: f, score: score, today: today, now: now),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Tide.turuncu,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _sharing ? null : () => _share(f, score),
                        icon: const Icon(Icons.ios_share),
                        label: Text(_sharing ? 'Hazırlanıyor…' : 'Raporu paylaş (Instagram, WhatsApp, Facebook)'),
                      ),
                    ),
                  ),
                  const BaitCard(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      'Hava ve deniz verileri Open-Meteo modellerinden alınır. Av verimliliği; ay evresi, rüzgâr, '
                      'dalga ve basınç eğiliminden hesaplanan bir tahmindir.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF77766A)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Paylaşılan görselin kendisi — tek başına anlamlı ve markalı olmalı
class _ReportCard extends StatelessWidget {
  final SpotForecast f;
  final int score;
  final DayForecast? today;
  final DateTime now;
  const _ReportCard({required this.f, required this.score, required this.today, required this.now});

  @override
  Widget build(BuildContext context) {
    final r = f.now;
    final trend = f.pressureTrend;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2530), Color(0xFF0E3B43), Color(0xFF123F3A)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Başlık
        Row(children: [
          ClipOval(
            child: Image.asset('assets/brand/logo.png',
                width: 38, height: 38, errorBuilder: (_, __, ___) => const SizedBox(width: 38, height: 38)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${f.spot.name} · ${f.spot.side == Side.anadolu ? 'Anadolu Yakası' : 'Avrupa Yakası'}',
                  style: const TextStyle(color: Color(0xFFBFD6D1), fontSize: 12.5, fontWeight: FontWeight.w700)),
              Text('${_tarih(now)} · ${_gunler[now.weekday - 1]}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        // Verimlilik halkası + ay
        Row(children: [
          SizedBox(
            width: 128,
            height: 128,
            child: CustomPaint(
              painter: _ScoreRing(score / 100),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('%$score',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  Text(FishingScore.label(score),
                      style: const TextStyle(color: Color(0xFFFFC9A8), fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AV VERİMLİLİĞİ',
                  style: TextStyle(color: Color(0xFF8FB0AA), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(width: 34, height: 34, child: CustomPaint(painter: MoonPainter(now))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Moon.phaseName(now),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('%${(Moon.illumination(now) * 100).round()} aydınlık',
                        style: const TextStyle(color: Color(0xFF9FC4BD), fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              _FishRow(FishingScore.fishCount(score)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Text(r.verdict,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        // Hava / deniz ölçümleri
        Wrap(spacing: 10, runSpacing: 10, children: [
          _chip(Icons.air, 'Rüzgâr', '${r.windKmh?.round() ?? '-'} km/s ${r.windFrom}'),
          _chip(Icons.waves, 'Dalga (6 sa. en fazla)',
              r.strait ? 'Boğaz içi' : (r.waveM == null ? '—' : '${r.waveM!.toStringAsFixed(1)} m (${r.effectiveWave.toStringAsFixed(1)} m)')),
          if (r.gustKmh != null) _chip(Icons.storm, 'Hamle', '${r.gustKmh!.round()} km/s'),
          if (r.rainDay != null) _chip(Icons.water_drop_outlined, 'Yağış (gün)', '${r.rainDay!.toStringAsFixed(r.rainDay! < 10 ? 1 : 0)} mm'),
          _chip(Icons.thermostat, 'Su / Hava', '${r.seaC?.round() ?? '-'}° / ${r.airC?.round() ?? '-'}°'),
          _chip(Icons.speed, 'Basınç',
              r.pressure == null ? '—' : '${r.pressure!.round()} hPa ${trend == null ? '' : (trend < -0.8 ? '↘' : trend > 0.8 ? '↗' : '→')}'),
        ]),
        const SizedBox(height: 16),
        // En iyi saatler
        const Text('EN VERİMLİ SAATLER',
            style: TextStyle(color: Color(0xFF8FB0AA), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _window('Sabah', today?.sunrise, Icons.wb_twilight)),
          const SizedBox(width: 10),
          Expanded(child: _window('Akşam', today?.sunset, Icons.nights_stay_outlined)),
        ]),
        const SizedBox(height: 16),
        // 7 günlük tablo
        const Text('7 GÜNLÜK TAHMİN',
            style: TextStyle(color: Color(0xFF8FB0AA), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final d in f.days) _dayRow(d),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.phishing, color: Tide.turuncu, size: 16),
          SizedBox(width: 6),
          Text('KıyıdanAv · kiyidanav.com',
              style: TextStyle(color: Color(0xFFBFD6D1), fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      ]),
    );
  }

  Widget _chip(IconData i, String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: const Color(0xFF9FC4BD), size: 16),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(color: Color(0xFF8FB0AA), fontSize: 10.5)),
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );

  Widget _window(String label, DateTime? t, IconData icon) {
    final from = t?.subtract(const Duration(hours: 1));
    final to = t?.add(const Duration(hours: 1));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0x1FF46C22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55F46C22))),
      child: Row(children: [
        Icon(icon, color: Tide.turuncu, size: 20),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFFFFC9A8), fontSize: 11.5)),
          Text('${_saat(from)} – ${_saat(to)}',
              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _dayRow(DayForecast d) {
    final s = FishingScore.compute(d.date.add(const Duration(hours: 12)),
        windKmh: d.effectiveWind, waveM: d.waveMax, rainMm: d.rainSum);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 84,
          child: Text('${d.day} ${ayAdlari[d.date.month].substring(0, 3)}\n${_gunler[d.date.weekday - 1]}',
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.25, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
            width: 22, height: 22, child: CustomPaint(painter: MoonPainter(d.date.add(const Duration(hours: 21))))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${d.windMax?.round() ?? '-'}/${d.gustMax?.round() ?? '-'} km/s · ${d.waveMax == null ? '—' : '${d.waveMax!.toStringAsFixed(1)} m'}${(d.rainSum ?? 0) >= 1 ? ' · ${d.rainSum!.round()} mm' : ''}',
            style: const TextStyle(color: Color(0xFF9FC4BD), fontSize: 12),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: _scoreColor(s), borderRadius: BorderRadius.circular(7)),
          child: Text('%$s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
        const SizedBox(width: 6),
        _FishRow(FishingScore.fishCount(s), size: 12),
      ]),
    );
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF2E8B57);
    if (s >= 60) return const Color(0xFFC98A1B);
    return const Color(0xFFB0413E);
  }
}

extension on DayForecast {
  int get day => date.day;
}

class _FishRow extends StatelessWidget {
  final int count;
  final double size;
  const _FishRow(this.count, {this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++)
        Icon(Icons.set_meal, size: size, color: i < count ? const Color(0xFF4FC3F7) : const Color(0x33FFFFFF)),
    ]);
  }
}

class _ScoreRing extends CustomPainter {
  final double v;
  _ScoreRing(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final bg = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Color(0xFFF46C22), Color(0xFFFFB74D), Color(0xFF4FC3F7)],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * v.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(_ScoreRing old) => old.v != v;
}

/// Ayın o günkü görünümü (aydınlık kısım hesapla çizilir)
class MoonPainter extends CustomPainter {
  final DateTime t;
  MoonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2B3A40));
    final k = Moon.illumination(t); // 0..1
    final waxing = Moon.waxing(t);
    final lit = Paint()..color = const Color(0xFFF3EFD9);
    // Aydınlık yarım + terminatör elipsi
    final half = Rect.fromCircle(center: c, radius: r);
    final path = Path()
      ..addArc(half, -math.pi / 2, waxing ? math.pi : -math.pi)
      ..close();
    final ex = r * (1 - 2 * k).abs();
    final ell = Rect.fromCenter(center: c, width: ex * 2, height: r * 2);
    final ellPath = Path()..addOval(ell);
    if (k >= 0.5) {
      canvas.drawPath(Path.combine(PathOperation.union, path, ellPath), lit);
    } else {
      canvas.drawPath(Path.combine(PathOperation.difference, path, ellPath), lit);
    }
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x55FFFFFF));
  }

  @override
  bool shouldRepaint(MoonPainter old) => old.t != t;
}
