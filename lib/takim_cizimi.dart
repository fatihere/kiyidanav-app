import 'package:flutter/material.dart';

import 'theme.dart';

/// 1.14.0 — Kıyıdabiri: "Mantarlı takım nasıl bağlanır?" çizimi.
/// Kurşun dipte durur; fırdöndüden sonraki köstek, iğnenin biraz üstündeki mantar (köpük yüzdürücü)
/// sayesinde dipten kalkar ve fileto yem akıntıda oynar.
class MantarliTakimCizimi extends StatelessWidget {
  const MantarliTakimCizimi({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCFE0E3)),
        ),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(painter: _MantarliBoyaci(DefaultTextStyle.of(context).style.fontFamily)),
        ),
      );
}

class _MantarliBoyaci extends CustomPainter {
  final String? font;
  _MantarliBoyaci(this.font);

  void _yazi(Canvas c, String s, Offset o, double w,
      {double boy = 10.5, Color renk = const Color(0xFF2B2A20), bool kalin = false, TextAlign hiza = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: font, fontSize: boy, color: renk, height: 1.2, fontWeight: kalin ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
      textAlign: hiza,
    )..layout(maxWidth: w);
    tp.paint(c, o);
  }

  void _ok(Canvas c, Offset a, Offset b) {
    final p = Paint()
      ..color = const Color(0xFF8A8A7A)
      ..strokeWidth = 1;
    c.drawLine(a, b, p);
    c.drawCircle(b, 2, p);
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final su = Paint()..shader = const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD7ECF0), Color(0xFFB9DBE2)])
        .createShader(Offset.zero & s);
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(12)), su);
    // dip
    final dipY = h * .86;
    final dip = Path()..moveTo(0, dipY);
    for (var x = 0.0; x <= w; x += 8) {
      dip.lineTo(x, dipY + ((x ~/ 8).isEven ? 2 : -1));
    }
    dip
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(dip, Paint()..color = const Color(0xFFD9C9A3));
    _yazi(c, 'Dip (kum / taşlık)', Offset(w * .03, dipY + 18), w * .3, boy: 9.5, renk: const Color(0xFF6B5B3A));

    final misina = Paint()
      ..color = const Color(0xFF1F3A44)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    // ana beden: yukarıdan kurşuna
    final kursun = Offset(w * .22, dipY - 8);
    c.drawLine(Offset(w * .06, 0), kursun, misina);
    // kayar zeytin kurşun
    c.save();
    c.translate(kursun.dx, kursun.dy);
    c.rotate(.35);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 26, height: 13), Paint()..color = const Color(0xFF5E6870));
    c.restore();
    // boncuk + fırdöndü
    final boncuk = Offset(w * .29, dipY - 7);
    c.drawCircle(boncuk, 3.5, Paint()..color = Tide.turuncu);
    final fir = Offset(w * .34, dipY - 8);
    final halka = Paint()
      ..color = const Color(0xFF3B3B3B)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    c.drawOval(Rect.fromCenter(center: fir.translate(-3, 0), width: 7, height: 5), halka);
    c.drawOval(Rect.fromCenter(center: fir.translate(4, 0), width: 7, height: 5), halka);
    // köstek: fırdöndüden mantara yükselir, iğneye hafif iner
    final mantar = Offset(w * .70, h * .40);
    final igne = Offset(w * .80, h * .55);
    final kostek = Path()
      ..moveTo(fir.dx + 8, fir.dy)
      ..cubicTo(w * .50, dipY - 10, w * .58, h * .50, mantar.dx, mantar.dy);
    c.drawPath(kostek, misina..color = const Color(0xFF3A8FA0));
    // çelik tel (lüfer için)
    c.drawLine(mantar, igne.translate(-2, -10), Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 2.2);
    // mantar (köpük yüzdürücü)
    c.drawOval(Rect.fromCenter(center: mantar, width: 22, height: 16), Paint()..color = Tide.turuncu);
    c.drawOval(Rect.fromCenter(center: mantar.translate(0, 3), width: 22, height: 8), Paint()..color = Colors.white);
    // iğne (uzun gövdeli) + fileto hamsi
    final ip = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final ig = Path()
      ..moveTo(igne.dx - 2, igne.dy - 10)
      ..lineTo(igne.dx - 2, igne.dy + 10)
      ..arcToPoint(igne.translate(10, 10), radius: const Radius.circular(6), clockwise: false)
      ..lineTo(igne.dx + 10, igne.dy + 4);
    c.drawPath(ig, ip);
    final fileto = Path()
      ..moveTo(igne.dx - 6, igne.dy - 6)
      ..quadraticBezierTo(igne.dx + 14, igne.dy, igne.dx + 4, igne.dy + 22)
      ..quadraticBezierTo(igne.dx - 4, igne.dy + 10, igne.dx - 6, igne.dy - 6)
      ..close();
    c.drawPath(fileto, Paint()..color = const Color(0xCCB8C6CC));
    c.drawPath(fileto, Paint()
      ..color = const Color(0xFF7A8E96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    // akıntı okları
    final ak = Paint()
      ..color = const Color(0x553A8FA0)
      ..strokeWidth = 2;
    for (final y in [h * .30, h * .34]) {
      c.drawLine(Offset(w * .36, y), Offset(w * .52, y), ak);
      c.drawLine(Offset(w * .52, y), Offset(w * .49, y - 3), ak);
      c.drawLine(Offset(w * .52, y), Offset(w * .49, y + 3), ak);
    }
    _yazi(c, 'akıntı', Offset(w * .36, h * .245), 60, boy: 9, renk: const Color(0xFF3A8FA0));

    // etiketler
    _yazi(c, 'Mantarlı takım (yemli çinekop – lüfer)', Offset(w * .04, h * .025), w * .92, boy: 12, kalin: true, renk: Tide.derin);
    _ok(c, Offset(w * .13, h * .19), Offset(w * .095, h * .19));
    _yazi(c, '1. Ana beden\n0,30–0,35 mm', Offset(w * .135, h * .14), w * .3);
    _ok(c, Offset(w * .74, h * .25), mantar.translate(0, -8));
    _yazi(c, '5. Mantar (yüzdürücü)\niğneden 20–30 cm yukarıda', Offset(w * .52, h * .12), w * .46, boy: 9.5);
    _yazi(c, '4. Köstek 0,28–0,30 mm\nflorokarbon, 80–120 cm', Offset(w * .25, h * .40), w * .3, boy: 9.5);
    _ok(c, Offset(w * .27, h * .735), kursun.translate(4, -6));
    _yazi(c, '2. Kayar zeytin\nkurşun 30–80 g', Offset(w * .26, h * .655), w * .3);
    _ok(c, Offset(w * .40, h * .90), fir.translate(0, 3));
    _yazi(c, '3. Boncuk + fırdöndü', Offset(w * .41, h * .885), w * .4, renk: const Color(0xFF4A3F28));
    _yazi(c, '6. Çelik tel 10–15 cm\n(iri lüfer için)', Offset(w * .83, h * .36), w * .17, boy: 8.5);
    _ok(c, Offset(w * .76, h * .64), igne.translate(2, 16));
    _yazi(c, '7. Uzun gövdeli iğne\n1–2 / 1/0–2/0\n+ fileto hamsi / istavrit', Offset(w * .58, h * .64), w * .42, boy: 9);
  }

  @override
  bool shouldRepaint(_MantarliBoyaci o) => o.font != font;
}
