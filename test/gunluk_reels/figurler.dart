// Günlük Reels — çizilmiş figürler: türe özel balıklar ve atış yapan balıkçı silüeti
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Bir türün çizim özellikleri (gövde oranı, renkler, yüzgeç ve kuyruk biçimi)
class TurStil {
  final String ad;
  final double boy, kuyruk, catal, alin; // gövde yüksekliği/boy, kuyruk açıklığı, kuyruk çatalı, alın yuvarlaklığı
  final Color sirt, yan, karin, yuzgec;
  final bool ikiSirt, cizgili, altinBant, kuyrukBandi, kalinYanCizgi;
  const TurStil(this.ad,
      {required this.boy,
      required this.sirt,
      required this.yan,
      required this.karin,
      required this.yuzgec,
      this.kuyruk = 0.36,
      this.catal = 0.08,
      this.alin = 1.0,
      this.ikiSirt = true,
      this.cizgili = false,
      this.altinBant = false,
      this.kuyrukBandi = false,
      this.kalinYanCizgi = false});

  static const levrek = TurStil('Levrek',
      boy: 0.29, sirt: Color(0xFF3F4E5A), yan: Color(0xFFB4BEC6), karin: Color(0xFFF1F4F6), yuzgec: Color(0xFF55636E), alin: 0.85);
  static const lufer = TurStil('Lüfer',
      boy: 0.27, sirt: Color(0xFF1F6C78), yan: Color(0xFF8DBCC2), karin: Color(0xFFEAF3F3), yuzgec: Color(0xFF2D5D66), kuyruk: 0.44, catal: 0.13);
  static const cipura = TurStil('Çipura',
      boy: 0.46, sirt: Color(0xFF66747E), yan: Color(0xFFCAD2D7), karin: Color(0xFFF4F6F7), yuzgec: Color(0xFF6D7880), kuyruk: 0.42,
      catal: 0.11, alin: 1.45, ikiSirt: false, altinBant: true);
  static const karagoz = TurStil('Karagöz',
      boy: 0.44, sirt: Color(0xFF6F7880), yan: Color(0xFFC6CDD2), karin: Color(0xFFF3F5F6), yuzgec: Color(0xFF59626A), kuyruk: 0.40,
      catal: 0.11, alin: 1.3, ikiSirt: false, kuyrukBandi: true);
  static const kefal = TurStil('Kefal',
      boy: 0.23, sirt: Color(0xFF3A464E), yan: Color(0xFF9DA8AF), karin: Color(0xFFE6EAEC), yuzgec: Color(0xFF4A555C), alin: 0.75,
      catal: 0.07, cizgili: true);
  static const istavrit = TurStil('İstavrit',
      boy: 0.25, sirt: Color(0xFF3B6E8E), yan: Color(0xFFBBCDD8), karin: Color(0xFFF3F7F9), yuzgec: Color(0xFFD9B64A), kuyruk: 0.42,
      catal: 0.13, kalinYanCizgi: true);
  static const palamut = TurStil('Palamut',
      boy: 0.25, sirt: Color(0xFF26445E), yan: Color(0xFF9FB5C4), karin: Color(0xFFEFF3F5), yuzgec: Color(0xFF2E4A60), kuyruk: 0.46,
      catal: 0.15, cizgili: true);

  static const _buyukler = [levrek, lufer, cipura, karagoz, kefal, palamut];
  static const _kucukler = [istavrit];

  static TurStil? _bul(String ad, List<TurStil> l) {
    final a = ad.toLowerCase();
    for (final s in l) {
      if (a.startsWith(s.ad.toLowerCase().substring(0, 3))) return s;
    }
    return null;
  }

  /// Günün türlerinden kesitte görünecek büyük ve küçük balık
  static (TurStil, TurStil) sec(List<String> turler) {
    TurStil? b, k;
    for (final t in turler) {
      b ??= _bul(t, _buyukler);
      k ??= _bul(t, _kucukler);
    }
    return (b ?? levrek, k ?? istavrit);
  }
}

/// Türe özel balık. [o] gövde merkezi, [L] boy, [t] zaman (kuyruk sallanır), [parlama] alttaki ışık halesi rengi
void turCiz(Canvas c, Offset o, double L, TurStil st, {bool sola = false, double t = 0, Color? hale}) {
  final h = L * st.boy;
  c.save();
  c.translate(o.dx, o.dy);
  if (sola) c.scale(-1, 1);

  final govde = Path()
    ..moveTo(L * 0.5, h * 0.04)
    ..cubicTo(L * 0.46, -h * 0.42 * st.alin, L * 0.12, -h * 0.58, -L * 0.30, -h * 0.15)
    ..lineTo(-L * 0.36, -h * 0.09)
    ..lineTo(-L * 0.36, h * 0.09)
    ..lineTo(-L * 0.30, h * 0.15)
    ..cubicTo(L * 0.06, h * 0.56, L * 0.40, h * 0.44, L * 0.5, h * 0.04)
    ..close();

  // kuyruk (sallanır)
  final kuyruk = Path()
    ..moveTo(-L * 0.34, -h * 0.08)
    ..quadraticBezierTo(-L * 0.44, -h * st.kuyruk * 0.9, -L * 0.53, -h * st.kuyruk * 1.25)
    ..quadraticBezierTo(-L * (0.50 - st.catal), 0, -L * 0.53, h * st.kuyruk * 1.25)
    ..quadraticBezierTo(-L * 0.44, h * st.kuyruk * 0.9, -L * 0.34, h * 0.08)
    ..close();
  final w = math.sin(t * 9) * 0.16;
  final kuyrukD = kuyruk.transform((Matrix4.identity()
        ..translate(-L * 0.35, 0.0)
        ..rotateZ(w)
        ..translate(L * 0.35, 0.0))
      .storage);

  // yüzgeçler
  final sirt = Path();
  if (st.ikiSirt) {
    sirt
      ..moveTo(L * 0.12, -h * 0.44)
      ..lineTo(L * 0.06, -h * 0.80)
      ..lineTo(-L * 0.04, -h * 0.74)
      ..lineTo(-L * 0.08, -h * 0.40)
      ..close()
      ..moveTo(-L * 0.11, -h * 0.38)
      ..quadraticBezierTo(-L * 0.16, -h * 0.66, -L * 0.27, -h * 0.30)
      ..close();
  } else {
    sirt
      ..moveTo(L * 0.16, -h * 0.47)
      ..quadraticBezierTo(L * 0.0, -h * 0.80, -L * 0.27, -h * 0.26)
      ..lineTo(-L * 0.20, -h * 0.32)
      ..close();
  }
  final anal = Path()
    ..moveTo(-L * 0.10, h * 0.36)
    ..quadraticBezierTo(-L * 0.17, h * 0.62, -L * 0.27, h * 0.24)
    ..close();
  final karinY = Path()
    ..moveTo(L * 0.14, h * 0.40)
    ..quadraticBezierTo(L * 0.08, h * 0.66, L * 0.02, h * 0.42)
    ..close();
  final gogus = Path()
    ..moveTo(L * 0.25, h * 0.06)
    ..quadraticBezierTo(L * 0.10, h * 0.10, L * 0.08, h * 0.30)
    ..quadraticBezierTo(L * 0.18, h * 0.22, L * 0.25, h * 0.06)
    ..close();

  if (hale != null) {
    final butun = Path()
      ..addPath(govde, Offset.zero)
      ..addPath(kuyrukD, Offset.zero);
    c.drawPath(butun, Paint()
      ..color = hale.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, L * 0.10));
  }
  final yuzP = Paint()..color = st.yuzgec.withValues(alpha: 0.92);
  c.drawPath(sirt, yuzP);
  c.drawPath(anal, yuzP);
  c.drawPath(karinY, yuzP);
  c.drawPath(kuyrukD, Paint()..color = st.yuzgec);
  if (st.kuyrukBandi) {
    c.drawRect(Rect.fromLTRB(-L * 0.36, -h * 0.12, -L * 0.31, h * 0.12), Paint()..color = const Color(0xFF15181B));
  }
  // gövde: sırt → yan → karın
  c.drawPath(govde, Paint()
    ..shader = ui.Gradient.linear(Offset(0, -h * 0.55), Offset(0, h * 0.5), [st.sirt, st.yan, st.karin], const [0.05, 0.5, 0.95]));
  c.save();
  c.clipPath(govde);
  if (st.cizgili) {
    for (var i = 0; i < 4; i++) {
      final y = -h * 0.30 + i * h * 0.12;
      c.drawLine(Offset(L * 0.40, y), Offset(-L * 0.36, y * 0.6), Paint()
        ..color = st.sirt.withValues(alpha: 0.35)
        ..strokeWidth = h * 0.035);
    }
  }
  if (st.altinBant) {
    c.drawLine(Offset(L * 0.38, -h * 0.40), Offset(L * 0.40, -h * 0.05), Paint()
      ..color = const Color(0xFFE8B931)
      ..strokeWidth = h * 0.07
      ..strokeCap = StrokeCap.round);
  }
  // pul parıltısı
  c.drawRect(Rect.fromLTRB(-L * 0.5, -h * 0.5, L * 0.5, 0), Paint()
    ..shader = ui.Gradient.linear(Offset(0, -h * 0.45), Offset.zero, [Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.22)]));
  c.restore();
  // yan çizgi, solungaç, ağız
  c.drawPath(
      Path()
        ..moveTo(L * 0.30, -h * 0.20)
        ..quadraticBezierTo(L * 0.0, -h * 0.30, -L * 0.35, -h * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = st.kalinYanCizgi ? h * 0.05 : h * 0.018
        ..color = (st.kalinYanCizgi ? st.sirt : Colors.black).withValues(alpha: st.kalinYanCizgi ? 0.6 : 0.28));
  c.drawArc(Rect.fromCenter(center: Offset(L * 0.30, h * 0.0), width: h * 0.6, height: h * 0.75), -1.2, 2.2, false, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.025
    ..color = Colors.black.withValues(alpha: 0.30));
  c.drawLine(Offset(L * 0.50, h * 0.05), Offset(L * 0.43, h * 0.09), Paint()
    ..strokeWidth = h * 0.02
    ..color = Colors.black.withValues(alpha: 0.45));
  c.drawPath(gogus, Paint()..color = st.yuzgec.withValues(alpha: 0.75));
  // göz
  final g = Offset(L * 0.40, -h * 0.10);
  c.drawCircle(g, L * 0.034, Paint()..color = const Color(0xFFF3E6B5));
  c.drawCircle(g, L * 0.022, Paint()..color = const Color(0xFF111111));
  c.drawCircle(g.translate(L * 0.008, -L * 0.008), L * 0.007, Paint()..color = Colors.white);
  c.restore();
}

/// Atış yapan balıkçı silüeti. [ayak]: iki ayağın ortası, [boy] piksel boyu, [aci] kamış açısı (radyan, 0 = yatay sağ),
/// [bukum] kamışın esnemesi (-1..1). Kamış ucunun konumunu döndürür.
Offset balikciCiz(Canvas c, Offset ayak, double boy, double aci, double bukum, Color govde, Color kenar) {
  final b = boy;
  Offset p(double x, double y) => ayak.translate(x * b, y * b);
  final dolgu = Paint()..color = govde;
  final cizgi = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = kenar.withValues(alpha: 0.75);

  final beden = Path()
    // bacaklar ve çizmeler
    ..moveTo(p(-0.10, 0).dx, p(-0.10, 0).dy)
    ..lineTo(p(-0.02, 0).dx, p(-0.02, 0).dy)
    ..lineTo(p(-0.01, -0.40).dx, p(-0.01, -0.40).dy)
    ..lineTo(p(0.05, 0).dx, p(0.05, 0).dy)
    ..lineTo(p(0.14, 0).dx, p(0.14, 0).dy)
    ..lineTo(p(0.08, -0.47).dx, p(0.08, -0.47).dy)
    // mont (hafif öne eğik)
    ..lineTo(p(0.12, -0.52).dx, p(0.12, -0.52).dy)
    ..quadraticBezierTo(p(0.15, -0.70).dx, p(0.15, -0.70).dy, p(0.09, -0.80).dx, p(0.09, -0.80).dy)
    ..lineTo(p(-0.06, -0.80).dx, p(-0.06, -0.80).dy)
    ..quadraticBezierTo(p(-0.13, -0.66).dx, p(-0.13, -0.66).dy, p(-0.11, -0.47).dx, p(-0.11, -0.47).dy)
    ..close();
  c.drawPath(beden, dolgu);
  c.drawPath(beden, cizgi);
  // baş ve şapka
  final bas = p(0.03, -0.875);
  c.drawCircle(bas, b * 0.065, dolgu);
  c.drawCircle(bas, b * 0.065, cizgi);
  final sapka = Path()
    ..moveTo(p(-0.04, -0.90).dx, p(-0.04, -0.90).dy)
    ..quadraticBezierTo(p(0.03, -0.99).dx, p(0.03, -0.99).dy, p(0.09, -0.91).dx, p(0.09, -0.91).dy)
    ..lineTo(p(0.17, -0.89).dx, p(0.17, -0.89).dy)
    ..lineTo(p(0.16, -0.875).dx, p(0.16, -0.875).dy)
    ..lineTo(p(-0.04, -0.88).dx, p(-0.04, -0.88).dy)
    ..close();
  c.drawPath(sapka, dolgu);
  c.drawPath(sapka, cizgi);
  // eller kamış dipçiğinde; kamış dipçikten açıyla uzanır
  final dip = p(0.10, -0.60);
  final uz = b * 1.25;
  final yon = Offset(math.cos(aci), math.sin(aci));
  final dik = Offset(-yon.dy, yon.dx);
  final uc = dip + yon * uz + dik * (bukum * uz * 0.18);
  final orta = dip + yon * (uz * 0.55) + dik * (bukum * uz * 0.12);
  final kol = Paint()
    ..color = govde
    ..strokeWidth = b * 0.06
    ..strokeCap = StrokeCap.round;
  c.drawLine(p(0.04, -0.76), dip, kol);
  c.drawLine(p(-0.02, -0.74), dip - yon * (b * 0.12), kol);
  // kamış: dipte kalın, uca doğru incelen iki parça
  final kamis = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = govde;
  c.drawPath(Path()
    ..moveTo(dip.dx - yon.dx * b * 0.18, dip.dy - yon.dy * b * 0.18)
    ..quadraticBezierTo(dip.dx, dip.dy, orta.dx, orta.dy), kamis..strokeWidth = 9);
  c.drawPath(Path()
    ..moveTo(orta.dx, orta.dy)
    ..quadraticBezierTo((orta.dx + uc.dx) / 2 + dik.dx * bukum * 18, (orta.dy + uc.dy) / 2 + dik.dy * bukum * 18, uc.dx, uc.dy),
      kamis..strokeWidth = 4);
  // makara
  final makara = dip + yon * (b * 0.06) + dik * (b * 0.05);
  c.drawCircle(makara, b * 0.035, Paint()..color = kenar);
  return uc;
}
