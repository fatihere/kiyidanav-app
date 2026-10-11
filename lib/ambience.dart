import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sea.dart';

/// Mera Bilgisi kartının "havası": arka plan, hareketli efekt ve ortam sesi buna göre seçilir.
enum SeaMood {
  sakin('Sakin deniz', 'sakin', [Color(0xFF1F6E8C), Color(0xFF2C8BA6), Color(0xFF3F9AA0)]),
  ruzgar('Rüzgârlı', 'ruzgar', [Color(0xFF3B5870), Color(0xFF52708A), Color(0xFF6A8798)]),
  yagmur('Yağmurlu', 'yagmur', [Color(0xFF33475B), Color(0xFF465F77), Color(0xFF58738A)]),
  dalga('Dalgalı', 'dalga', [Color(0xFF103A5C), Color(0xFF1B5A82), Color(0xFF2A7193)]);

  final String label;
  final String sound; // assets/sounds/<sound>.ogg
  final List<Color> colors;
  const SeaMood(this.label, this.sound, this.colors);

  /// Önce tehlikeli durum (dalga/fırtına), sonra yağış, sonra rüzgâr
  static SeaMood of(SeaReport r, {double waveThreshold = 1.0}) {
    if ((!r.strait && r.effectiveWave >= waveThreshold) || r.effectiveWind >= 35) return SeaMood.dalga;
    if ((r.rainNow ?? 0) >= 0.3 || (r.rainDay ?? 0) >= 8) return SeaMood.yagmur;
    if (r.effectiveWind >= 22) return SeaMood.ruzgar;
    return SeaMood.sakin;
  }
}

/// Panelde "dinamik arka plan" kapatılırsa kullanılan sabit (eskisinden açık) zemin
const fixedMoodColors = [Color(0xFF15485A), Color(0xFF1C6070), Color(0xFF2A6F68)];

/// Kartın arkasında hafifçe hareket eden efekt: yağmur damlası, rüzgâr çizgisi, köpük, güneş yansıması
class MoodOverlay extends StatefulWidget {
  final SeaMood mood;
  final double intensity; // 0..1
  const MoodOverlay({super.key, required this.mood, this.intensity = 0.6});

  @override
  State<MoodOverlay> createState() => _MoodOverlayState();
}

class _MoodOverlayState extends State<MoodOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _MoodPainter(widget.mood, _c.value, widget.intensity.clamp(0.0, 1.0)),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _MoodPainter extends CustomPainter {
  final SeaMood mood;
  final double t;
  final double k;
  _MoodPainter(this.mood, this.t, this.k);

  // Sabit tohumlu konumlar: her karede aynı damlalar kayar (titreşme olmaz)
  static final _rnd = math.Random(11);
  static final _pts = List.generate(70, (_) => Offset(_rnd.nextDouble(), _rnd.nextDouble()));
  static final _spd = List.generate(70, (_) => 0.6 + _rnd.nextDouble() * 0.8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (mood) {
      case SeaMood.yagmur:
        final p = Paint()
          ..color = Colors.white.withAlpha((50 + 50 * k).round())
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        final n = (35 + 35 * k).round();
        for (var i = 0; i < n; i++) {
          final x = _pts[i].dx * w;
          final y = ((_pts[i].dy + t * 3 * _spd[i]) % 1.0) * h;
          canvas.drawLine(Offset(x, y), Offset(x - 3, y + 11), p);
        }
        break;
      case SeaMood.ruzgar:
        final p = Paint()
          ..color = Colors.white.withAlpha((28 + 40 * k).round())
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 14; i++) {
          final y = _pts[i].dy * h;
          final x = ((_pts[i].dx + t * 2 * _spd[i]) % 1.3 - 0.15) * w;
          final len = 40 + 50 * _spd[i];
          final path = Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(x + len * 0.5, y - 5, x + len, y);
          canvas.drawPath(path, p);
        }
        break;
      case SeaMood.dalga:
        for (var j = 0; j < 3; j++) {
          final base = h * (0.80 + j * 0.07);
          final amp = 6.0 + 8 * k;
          final path = Path()..moveTo(0, h);
          for (double x = 0; x <= w; x += 6) {
            path.lineTo(x, base + math.sin(x / w * 2 * math.pi * 2 + (t + j * 0.3) * 2 * math.pi) * amp);
          }
          path
            ..lineTo(w, h)
            ..close();
          canvas.drawPath(path, Paint()..color = Colors.white.withAlpha(14 + j * 6));
        }
        break;
      case SeaMood.sakin:
        // Sağ üstte yumuşak güneş ışığı ve yüzeyde parıltılar
        canvas.drawCircle(
          Offset(w * 0.86, h * 0.06),
          w * 0.45,
          Paint()
            ..shader = RadialGradient(colors: [const Color(0x40FFE8A3), const Color(0x00FFE8A3)])
                .createShader(Rect.fromCircle(center: Offset(w * 0.86, h * 0.06), radius: w * 0.45)),
        );
        final p = Paint()..color = Colors.white.withAlpha(40);
        for (var i = 0; i < 18; i++) {
          final a = (math.sin((t + _pts[i].dx) * 2 * math.pi) + 1) / 2;
          p.color = Colors.white.withAlpha((10 + 45 * a).round());
          canvas.drawCircle(Offset(_pts[i].dx * w, h * (0.55 + _pts[i].dy * 0.45)), 1.6, p);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_MoodPainter old) => old.t != t || old.mood != mood || old.k != k;
}

/// Ortam sesi (döngü). Yalnızca Mera Bilgisi ekranı açıkken ve kullanıcı açtıysa çalar.
class Ambience {
  static const _prefKey = 'mera_ses_v1';
  static final on = ValueNotifier<bool>(false);
  static AudioPlayer? _player;
  static String? _playing;
  static bool _loaded = false;

  /// Kullanıcının son tercihi; hiç seçmediyse paneldeki varsayılan
  static Future<void> load({required bool defaultOn}) async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      on.value = p.getBool(_prefKey) ?? defaultOn;
    } catch (_) {
      on.value = defaultOn;
    }
  }

  static Future<void> toggle() async {
    on.value = !on.value;
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, on.value);
    } catch (_) {}
    if (!on.value) await stop();
  }

  static Future<void> play(SeaMood mood, {double volume = 0.6}) async {
    if (!on.value) return;
    try {
      final p = _player ??= AudioPlayer();
      if (_playing == mood.sound && p.state == PlayerState.playing) {
        await p.setVolume(volume);
        return;
      }
      await p.stop();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/${mood.sound}.ogg'));
      _playing = mood.sound;
    } catch (e) {
      debugPrint('ortam sesi: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    _playing = null;
  }
}
