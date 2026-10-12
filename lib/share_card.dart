import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'theme.dart';

/// "Raporu paylaş" görseli: ekrandaki canlı (animasyonlu, uzun) kartın fotoğrafını çekmek yerine
/// 1080×1350 (Instagram dikey gönderi) boyutunda, doğrudan tuvale çizilen sade bir kart.
/// Ekran görüntüsü yöntemi bazı Android telefonlarda (Impeller) 20 sn+ donmaya yol açıyordu.
class ShareCardData {
  final String place; // Mera · yaka
  final String date; // 13 Ekim 2026 · Salı
  final int score;
  final String scoreLabel;
  final String moonName;
  final int moonPct;
  final String verdict;
  final List<(IconData, String, String)> chips; // simge, başlık, değer (en fazla 6)
  final String morning; // 06:10 – 08:10
  final String evening;
  final List<(String, int, IconData, Color)> days; // gün, puan, hava simgesi, simge rengi
  final List<Color> colors; // arka plan geçişi
  final CustomPainter? moon;

  const ShareCardData({
    required this.place,
    required this.date,
    required this.score,
    required this.scoreLabel,
    required this.moonName,
    required this.moonPct,
    required this.verdict,
    this.chips = const [],
    this.morning = '',
    this.evening = '',
    this.days = const [],
    this.colors = const [Color(0xFF15485A), Color(0xFF1C6070), Color(0xFF2A6F68)],
    this.moon,
  });
}

class ShareCard {
  static const width = 1080;
  static const height = 1350;
  static ui.Image? _logo;

  static Color scoreColor(int s) {
    if (s >= 80) return const Color(0xFF2E8B57);
    if (s >= 60) return const Color(0xFFC98A1B);
    return const Color(0xFFB0413E);
  }

  static Future<ui.Image?> _loadLogo() async {
    if (_logo != null) return _logo;
    try {
      final data = await rootBundle.load('assets/brand/logo.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 112);
      return _logo = (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// PNG baytları
  static Future<Uint8List?> render(ShareCardData d, {bool withLogo = true}) async {
    final logo = withLogo ? await _loadLogo() : null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    paint(c, d, logo: logo);
    final pic = rec.endRecording();
    final img = await pic.toImage(width, height);
    pic.dispose();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes?.buffer.asUint8List();
  }

  static void paint(Canvas c, ShareCardData d, {ui.Image? logo}) {
    const w = 1080.0, h = 1350.0, pad = 64.0;
    final full = const Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: d.colors.length >= 2 ? d.colors : const [Color(0xFF15485A), Color(0xFF2A6F68)])
              .createShader(full));

    // Başlık
    var x = pad;
    if (logo != null) {
      final r = Rect.fromLTWH(pad, 60, 104, 104);
      c.save();
      c.clipPath(Path()..addOval(r));
      c.drawImageRect(logo, Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()), r,
          Paint()..filterQuality = FilterQuality.medium);
      c.restore();
      x = pad + 128;
    }
    _text(c, d.place, Offset(x, 66), size: 30, color: const Color(0xFFBFD6D1), weight: FontWeight.w700, maxWidth: w - x - pad);
    _text(c, d.date, Offset(x, 106), size: 44, weight: FontWeight.w800, maxWidth: w - x - pad);

    // Verimlilik halkası
    const ringC = Offset(pad + 150, 340);
    const ringR = 136.0;
    c.drawCircle(
        ringC,
        ringR,
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26);
    final ringRect = Rect.fromCircle(center: ringC, radius: ringR);
    c.drawArc(
        ringRect,
        -math.pi / 2,
        2 * math.pi * (d.score / 100).clamp(0.0, 1.0),
        false,
        Paint()
          ..shader = const SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [Color(0xFFF46C22), Color(0xFFFFB74D), Color(0xFF4FC3F7)],
          ).createShader(ringRect)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 26);
    _textCenter(c, '%${d.score}', Offset(ringC.dx, ringC.dy - 62), size: 88, weight: FontWeight.w800);
    _textCenter(c, d.scoreLabel, Offset(ringC.dx, ringC.dy + 40), size: 30, color: const Color(0xFFFFC9A8), weight: FontWeight.w700);

    // Ay
    const rx = pad + 340;
    _text(c, 'AV VERİMLİLİĞİ', const Offset(rx, 232), size: 26, color: const Color(0xFFCFE3E0), weight: FontWeight.w700, letter: 3);
    if (d.moon != null) {
      c.save();
      c.translate(rx, 288);
      d.moon!.paint(c, const Size(84, 84));
      c.restore();
    }
    final mx = d.moon != null ? rx + 108 : rx;
    _text(c, d.moonName, Offset(mx, 290), size: 38, weight: FontWeight.w800, maxWidth: w - mx - pad);
    _text(c, '%${d.moonPct} aydınlık', Offset(mx, 340), size: 30, color: const Color(0xFFD6E9E6));
    _text(c, '🐟' * (d.score / 20).ceil().clamp(1, 5).toInt(), const Offset(rx, 402), size: 40);

    // Yorum
    _text(c, d.verdict, const Offset(pad, 500), size: 42, weight: FontWeight.w800, maxWidth: w - 2 * pad, maxLines: 2);

    // Ölçümler (2 sütun × 3 satır)
    const cw = (w - 2 * pad - 24) / 2, ch = 96.0;
    final chips = d.chips.take(6).toList();
    for (var i = 0; i < chips.length; i++) {
      final (icon, k, v) = chips[i];
      final o = Offset(pad + (i % 2) * (cw + 24), 618 + (i ~/ 2) * (ch + 16));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, cw, ch), const Radius.circular(22)),
          Paint()..color = const Color(0x1FFFFFFF));
      _icon(c, icon, o + const Offset(22, 26), 44, const Color(0xFFD6E9E6));
      _text(c, k, o + const Offset(84, 14), size: 25, color: const Color(0xFFCFE3E0), maxWidth: cw - 100);
      _text(c, v, o + const Offset(84, 46), size: 33, weight: FontWeight.w700, maxWidth: cw - 100);
    }

    // En verimli saatler
    const hy = 966.0;
    for (var i = 0; i < 2; i++) {
      final o = Offset(pad + i * (cw + 24), hy);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, cw, 92), const Radius.circular(22)),
          Paint()..color = const Color(0x1FF46C22));
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, cw, 92), const Radius.circular(22)),
          Paint()
            ..color = const Color(0x55F46C22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _icon(c, i == 0 ? Icons.wb_twilight : Icons.nights_stay_outlined, o + const Offset(22, 22), 46, Tide.turuncu);
      _text(c, i == 0 ? 'Sabah' : 'Akşam', o + const Offset(84, 10), size: 25, color: const Color(0xFFFFC9A8));
      _text(c, i == 0 ? d.morning : d.evening, o + const Offset(84, 42), size: 34, weight: FontWeight.w800);
    }

    // Günler
    final days = d.days.take(7).toList();
    if (days.isNotEmpty) {
      final dw = (w - 2 * pad) / days.length;
      for (var i = 0; i < days.length; i++) {
        final (label, s, icon, color) = days[i];
        final cx = pad + dw * i + dw / 2;
        _textCenter(c, label, Offset(cx, 1080), size: 27, color: const Color(0xFFCFE3E0), weight: FontWeight.w700);
        _icon(c, icon, Offset(cx - 24, 1122), 48, color);
        final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 1210), width: 104, height: 50), const Radius.circular(14));
        c.drawRRect(pill, Paint()..color = scoreColor(s));
        _textCenter(c, '%$s', Offset(cx, 1192), size: 29, weight: FontWeight.w800);
      }
    }

    _textCenter(c, 'KıyıdanAv · kiyidanav.com', const Offset(w / 2, 1276), size: 31, color: const Color(0xFFD7E6E3), weight: FontWeight.w700);
  }

  static TextPainter _tp(String s,
          {double size = 30,
          Color color = Colors.white,
          FontWeight weight = FontWeight.w400,
          double maxWidth = double.infinity,
          int maxLines = 1,
          double letter = 0}) =>
      TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontFamily: Tide.font, fontSize: size, color: color, fontWeight: weight, letterSpacing: letter, height: 1.2)),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  static void _text(Canvas c, String s, Offset o,
      {double size = 30,
      Color color = Colors.white,
      FontWeight weight = FontWeight.w400,
      double maxWidth = double.infinity,
      int maxLines = 1,
      double letter = 0}) {
    if (s.isEmpty) return;
    _tp(s, size: size, color: color, weight: weight, maxWidth: maxWidth, maxLines: maxLines, letter: letter).paint(c, o);
  }

  static void _textCenter(Canvas c, String s, Offset top,
      {double size = 30, Color color = Colors.white, FontWeight weight = FontWeight.w400}) {
    if (s.isEmpty) return;
    final tp = _tp(s, size: size, color: color, weight: weight);
    tp.paint(c, Offset(top.dx - tp.width / 2, top.dy));
  }

  static void _icon(Canvas c, IconData i, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(i.codePoint),
          style: TextStyle(fontFamily: i.fontFamily, package: i.fontPackage, fontSize: size, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }
}
