// Günlük Reels — görsel tasarım (9 Kasım 2026, 2. sürüm)
// Her gün farklı görünür ve görseller VERİDEN üretilir:
//  - 5 renk teması (şafak, turkuaz, gün batımı, gece, fırtına) gün gün döner; sert havada fırtına teması
//  - canlı deniz sahnesi: dalga yüksekliği gerçek dalgaya, rüzgâr çizgileri gerçek yön/hıza, bulutlar bulutluluğa,
//    gece temasında gerçek ay evresine göre çizilir
//  - mera sahnesinde İstanbul mini haritası ve nabız atan konum iğnesi, kesitte animasyonlu olta atışı,
//    çizilmiş balık silüetleri, kapanışta Kıyıdabiri robotu
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kiyidanav/kiyilama.dart';
import 'package:kiyidanav/solunar.dart';

import 'figurler.dart';
import 'veri.dart';

const double rw = 1080, rh = 1920;
const fBas = 'BarlowCX', fBasB = 'BarlowCB', fGov = 'BarlowSB', fGovM = 'BarlowM';

// ------------------------------------------------------------------ temalar
class Tema {
  final String ad;
  final List<Color> gok; // üstten ufka
  final List<Color> deniz; // ufuktan dibe
  final Color gunes, vurgu, vurgu2;
  final List<Color> cta;
  final bool gece, firtina;
  const Tema(this.ad, this.gok, this.deniz, this.gunes, this.vurgu, this.vurgu2, this.cta, {this.gece = false, this.firtina = false});

  static const safak = Tema('safak', [Color(0xFF2B1055), Color(0xFFD53A9D), Color(0xFFFFB677)], [Color(0xFF6A2C8C), Color(0xFF13163F)],
      Color(0xFFFFD28A), Color(0xFFFFD23F), Color(0xFFFF5E9C), [Color(0xFFFF5E62), Color(0xFFFF9966)]);
  static const turkuaz = Tema('turkuaz', [Color(0xFF0046B8), Color(0xFF3A7BFF), Color(0xFF9BE8FF)], [Color(0xFF00B4DB), Color(0xFF00305E)],
      Color(0xFFFFF6C2), Color(0xFFFFE600), Color(0xFFFF6B35), [Color(0xFF00C9A7), Color(0xFF0062E6)]);
  static const altin = Tema('altin', [Color(0xFF141E46), Color(0xFFC0392B), Color(0xFFF7B733)], [Color(0xFF8A3442), Color(0xFF10142E)],
      Color(0xFFFFE29A), Color(0xFFFFC93C), Color(0xFF2EF2C5), [Color(0xFFF7971E), Color(0xFFFF4E50)]);
  static const geceT = Tema('gece', [Color(0xFF02031A), Color(0xFF0F1C5C), Color(0xFF2E4CA8)], [Color(0xFF0B2E6B), Color(0xFF010514)],
      Color(0xFFF4F1D0), Color(0xFF5CFFC9), Color(0xFFFFB86B), [Color(0xFF4E54C8), Color(0xFF8F94FB)], gece: true);
  static const firtinaT = Tema('firtina', [Color(0xFF1B232B), Color(0xFF3A4753), Color(0xFF6C7A89)], [Color(0xFF1D3F44), Color(0xFF071417)],
      Color(0xFFCFD8DC), Color(0xFFFF5A4E), Color(0xFFFFD166), [Color(0xFFC0392B), Color(0xFF5E1A16)], firtina: true);
  static const hepsi = [safak, turkuaz, altin, geceT, firtinaT];

  static Tema sec(List<MeraGunu> uc, DateTime now, [String? zorla]) {
    for (final t in hepsi) {
      if (t.ad == zorla) return t;
    }
    if (uc.every((m) => m.sert)) return firtinaT;
    const l = [safak, turkuaz, altin, geceT];
    return l[now.difference(DateTime(now.year)).inDays % l.length];
  }
}

// ------------------------------------------------------------------ yardımcılar
double ease(double x) => Curves.easeOutCubic.transform(x.clamp(0.0, 1.0));
double geri(double x) => Curves.easeOutBack.transform(x.clamp(0.0, 1.0));

TextStyle ts(String f, double s, Color c, {double ls = 0, double h = 1.0, bool golge = true}) => TextStyle(
    fontFamily: f,
    fontFamilyFallback: const ['Emoji'],
    fontSize: s,
    color: c,
    letterSpacing: ls,
    height: h,
    decoration: TextDecoration.none,
    shadows: golge ? [Shadow(blurRadius: 26, offset: const Offset(0, 5), color: Colors.black.withValues(alpha: 0.45))] : null);

Widget sigdir(String metin, TextStyle st, {bool orta = false}) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: orta ? Alignment.center : Alignment.centerLeft,
    child: Text(metin, maxLines: 1, softWrap: false, style: st));

Widget cam(Widget child, {EdgeInsets p = const EdgeInsets.all(26), double r = 30, double koyu = 0.30}) => Container(
      padding: p,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: koyu),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 2),
      ),
      child: child,
    );

String buyukHarf(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
String kucukHarf(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
String ondalik(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
String gunAdi(DateTime d) {
  const g = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'];
  const a = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
  return '${d.day} ${a[d.month - 1]} · ${g[d.weekday - 1]}';
}

/// Balık silüeti (burun +x yönünde)
Path balikYolu(Offset c, double L) {
  final h = L * 0.40;
  return Path()
    ..moveTo(c.dx + L / 2, c.dy)
    ..cubicTo(c.dx + L * 0.28, c.dy - h * 0.78, c.dx - L * 0.18, c.dy - h * 0.62, c.dx - L * 0.30, c.dy - h * 0.10)
    ..lineTo(c.dx - L * 0.50, c.dy - h * 0.58)
    ..quadraticBezierTo(c.dx - L * 0.42, c.dy, c.dx - L * 0.50, c.dy + h * 0.58)
    ..lineTo(c.dx - L * 0.30, c.dy + h * 0.10)
    ..cubicTo(c.dx - L * 0.18, c.dy + h * 0.62, c.dx + L * 0.28, c.dy + h * 0.78, c.dx + L / 2, c.dy)
    ..close();
}

void balikCiz(Canvas c, Offset o, double L, Color renk, {bool sola = false, double parlama = 1}) {
  c.save();
  if (sola) {
    c.translate(o.dx * 2, 0);
    c.scale(-1, 1);
  }
  final p = balikYolu(o, L);
  if (parlama > 0) {
    c.drawPath(p, Paint()
      ..color = renk.withValues(alpha: 0.55 * parlama)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, L * 0.12));
  }
  c.drawPath(p, Paint()..color = renk);
  c.drawCircle(Offset(o.dx + L * 0.30, o.dy - L * 0.05), L * 0.035, Paint()..color = Colors.black87);
  c.restore();
}

class _BalikSimge extends CustomPainter {
  final TurStil st;
  _BalikSimge(this.st);
  @override
  void paint(Canvas c, Size s) => turCiz(c, s.center(Offset.zero), s.width * 0.95, st);
  @override
  bool shouldRepaint(_BalikSimge o) => false;
}

// ------------------------------------------------------------------ canlı deniz sahnesi
class Atmosfer extends CustomPainter {
  final Tema tm;
  final double t, ruzgar, ruzgarYon, dalga, ufuk;
  final int bulut;
  final DateTime gun;
  Atmosfer(this.tm, this.t, {required this.ruzgar, required this.ruzgarYon, required this.dalga, required this.bulut, required this.gun, this.ufuk = 0.6});

  @override
  void paint(Canvas c, Size s) {
    final H = s.height * ufuk;
    // gök
    c.drawRect(Rect.fromLTWH(0, 0, s.width, H),
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, H), tm.gok, const [0, 0.62, 1]));
    final rnd = math.Random(7);
    if (tm.gece) {
      for (var i = 0; i < 90; i++) {
        final x = rnd.nextDouble() * s.width, y = rnd.nextDouble() * H * 0.85, r = 1.2 + rnd.nextDouble() * 2.4;
        c.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.35 * math.sin(t * 3 + i)));
      }
    }
    // güneş / ay
    final gm = Offset(s.width * 0.72, H - (tm.gece ? 520 : 200));
    c.drawCircle(gm, 520, Paint()
      ..shader = ui.Gradient.radial(gm, 520, [tm.gunes.withValues(alpha: tm.firtina ? 0.15 : 0.55), tm.gunes.withValues(alpha: 0)]));
    if (tm.gece) {
      const r = 92.0;
      // gerçek ay evresi: aydınlık kısım = disk − kaydırılmış disk (karanlık taraf saydam, hafif "dünya ışığı")
      final disk = Path()..addOval(Rect.fromCircle(center: gm, radius: r));
      c.drawPath(disk, Paint()..color = tm.gunes.withValues(alpha: 0.10));
      final ayd = Moon.illumination(gun).clamp(0.0, 1.0); // 0..1
      final kay = (Moon.waxing(gun) ? -1 : 1) * 2 * r * ayd;
      final aydinlik = ayd > 0.97
          ? disk
          : Path.combine(PathOperation.difference, disk, Path()..addOval(Rect.fromCircle(center: gm.translate(kay, 0), radius: r * 1.02)));
      c.drawPath(aydinlik, Paint()..color = tm.gunes);
    } else if (!tm.firtina) {
      c.drawCircle(gm, 118, Paint()..color = tm.gunes);
    }
    // bulutlar
    final nb = (bulut / 17).round().clamp(tm.firtina ? 4 : 1, 7);
    for (var i = 0; i < nb; i++) {
      final hiz = 10 + ruzgar * 1.4;
      final x = ((rnd.nextDouble() * (s.width + 500) + t * hiz) % (s.width + 500)) - 250;
      final y = 260 + rnd.nextDouble() * (H - 620);
      final b = 120 + rnd.nextDouble() * 120;
      final p = Paint()..color = (tm.firtina ? const Color(0xFF9AA5B1) : Colors.white).withValues(alpha: tm.firtina ? 0.55 : 0.42);
      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: b * 2.2, height: b * 0.7), p);
      c.drawOval(Rect.fromCenter(center: Offset(x - b * 0.4, y - b * 0.18), width: b * 1.1, height: b * 0.75), p);
      c.drawOval(Rect.fromCenter(center: Offset(x + b * 0.35, y - b * 0.25), width: b * 1.2, height: b * 0.85), p);
    }
    // deniz
    c.drawRect(Rect.fromLTWH(0, H, s.width, s.height - H),
        Paint()..shader = ui.Gradient.linear(Offset(0, H), Offset(0, s.height), tm.deniz));
    // güneş/ay yansıması
    if (!tm.firtina) {
      for (var i = 0; i < 26; i++) {
        final y = H + 14 + i * 26.0;
        final w = (40 + i * 9) * (0.6 + 0.4 * math.sin(t * 5 + i * 1.7));
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(gm.dx + math.sin(t * 2 + i) * 14, y), width: w, height: 7),
                const Radius.circular(4)),
            Paint()..color = tm.gunes.withValues(alpha: (0.55 - i * 0.018).clamp(0.0, 1.0)));
      }
    }
    // dalga katmanları: genlik gerçek dalgaya, hız rüzgâra göre
    final genlik = 7 + dalga.clamp(0.0, 2.5) * 42;
    final hiz = 0.7 + ruzgar / 18;
    for (var i = 0; i < 6; i++) {
      final y0 = H + (i + 1) * (s.height - H) / 7;
      final a = genlik * (0.45 + i * 0.22);
      final dl = 230.0 + i * 70;
      final path = Path()..moveTo(0, s.height);
      for (double x = 0; x <= s.width + 20; x += 18) {
        path.lineTo(x, y0 + math.sin(x / dl * 2 * math.pi + t * hiz * (1 + i * 0.25) + i) * a);
      }
      path
        ..lineTo(s.width, s.height)
        ..close();
      final renk = Color.lerp(tm.deniz[0], tm.deniz[1], 0.25 + i * 0.13)!;
      c.drawPath(path, Paint()..color = renk.withValues(alpha: 0.55));
      final tepe = Path();
      for (double x = 0; x <= s.width + 20; x += 18) {
        final y = y0 + math.sin(x / dl * 2 * math.pi + t * hiz * (1 + i * 0.25) + i) * a;
        x == 0 ? tepe.moveTo(x, y) : tepe.lineTo(x, y);
      }
      c.drawPath(tepe, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.10 + dalga.clamp(0.0, 1.5) * 0.12));
    }
    // rüzgâr çizgileri: gerçek yönde (rüzgârın ESTİĞİ yöne doğru) ve hızda
    final gidis = (ruzgarYon + 180) * math.pi / 180;
    final dx = math.sin(gidis), dy = -math.cos(gidis) * 0.22;
    final boy = 50 + ruzgar * 5;
    final adet = (8 + ruzgar * 0.9).clamp(8, 40).round();
    for (var i = 0; i < adet; i++) {
      final bx = rnd.nextDouble() * s.width, by = 180 + rnd.nextDouble() * (H + 260);
      final yol = (t * (90 + ruzgar * 16) + rnd.nextDouble() * 2000) % (s.width + 600);
      final x = (bx + dx * yol) % (s.width + 300) - 150, y = by + dy * yol;
      c.drawLine(Offset(x, y), Offset(x - dx * boy, y - dy * boy), Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }
    // okunabilirlik: kenar kararması
    c.drawRect(Offset.zero & s, Paint()
      ..shader = ui.Gradient.radial(s.center(Offset.zero), s.height * 0.75,
          [Colors.transparent, Colors.black.withValues(alpha: 0.42)], const [0.45, 1]));
  }

  @override
  bool shouldRepaint(Atmosfer o) => true;
}

// ------------------------------------------------------------------ İstanbul mini haritası
class Harita extends CustomPainter {
  final List<List<Offset>> kara; // (boylam, enlem)
  final Offset pin;
  final double t;
  final Tema tm;
  Harita(this.kara, this.pin, this.t, this.tm);
  static const l0 = 28.15, l1 = 29.75, b0 = 40.66, b1 = 41.42;
  Offset _p(Offset g, Size s) => Offset((g.dx - l0) / (l1 - l0) * s.width, (1 - (g.dy - b0) / (b1 - b0)) * s.height);

  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(26));
    c.save();
    c.clipRRect(rr);
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [tm.deniz[0], tm.deniz[1]]));
    for (final r in kara) {
      if (r.length < 3) continue;
      final p = Path()..moveTo(_p(r.first, s).dx, _p(r.first, s).dy);
      for (final g in r.skip(1)) {
        final q = _p(g, s);
        p.lineTo(q.dx, q.dy);
      }
      p.close();
      c.drawPath(p, Paint()..color = Colors.white.withValues(alpha: 0.88));
      c.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.12));
    }
    final q = _p(pin, s);
    final f = (t * 1.2) % 1;
    c.drawCircle(q, 14 + f * 46, Paint()..color = tm.vurgu2.withValues(alpha: (1 - f) * 0.6));
    c.drawCircle(q, 16, Paint()..color = tm.vurgu2);
    c.drawCircle(q, 16, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white);
    final tp = TextPainter(
        text: TextSpan(text: '© OpenStreetMap', style: ts(fGovM, 15, Colors.black54, golge: false)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, Offset(s.width - tp.width - 10, s.height - tp.height - 6));
    c.restore();
    c.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(Harita o) => true;
}

// ------------------------------------------------------------------ kesit + olta atışı
class Kesit extends CustomPainter {
  final List<MapEntry<int, double>> profil;
  final Kiyilama k;
  final Tema tm;
  final double t;
  final TurStil buyukTur, kucukTur;
  Kesit(this.profil, this.k, this.tm, this.t, this.buyukTur, this.kucukTur);

  @override
  void paint(Canvas c, Size s) {
    final maxX = math.max(k.buyukMax + 20, 80).toDouble();
    final p = profil.isNotEmpty
        ? ([...profil]..sort((x, y) => x.key.compareTo(y.key)))
        : [const MapEntry(0, 0.5), MapEntry(k.sev, 4.0), MapEntry(k.sev + 15, 9.0), MapEntry(maxX.round(), 14.0)];
    final maxD = math.max(p.map((e) => e.value).fold<double>(0, math.max), 6.0) * 1.2;
    const ust = 300.0, kiyi = 170.0;
    double x(num m) => kiyi + (m / maxX).clamp(0.0, 1.0) * (s.width - kiyi - 20);
    double y(num d) => ust + (d / maxD) * (s.height - ust - 30);
    double dipte(double m) {
      for (var i = 1; i < p.length; i++) {
        if (p[i].key >= m) {
          final a = p[i - 1], b = p[i];
          final r = b.key == a.key ? 0 : (m - a.key) / (b.key - a.key);
          return a.value + (b.value - a.value) * r;
        }
      }
      return p.last.value;
    }

    // gök şeridi ve su
    c.drawRect(Rect.fromLTWH(0, 0, s.width, ust), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, ust), [tm.gok[1].withValues(alpha: 0), tm.gok[2]]));
    c.drawRect(Rect.fromLTWH(0, ust, s.width, s.height - ust),
        Paint()..shader = ui.Gradient.linear(const Offset(0, ust), Offset(0, s.height), [tm.deniz[0], tm.deniz[1]]));
    // ışık huzmeleri
    for (var i = 0; i < 6; i++) {
      final x0 = s.width * (0.1 + i * 0.17) + math.sin(t * 0.8 + i) * 30;
      final hz = Path()
        ..moveTo(x0, ust)
        ..lineTo(x0 + 70, ust)
        ..lineTo(x0 + 220, s.height)
        ..lineTo(x0 + 40, s.height)
        ..close();
      c.drawPath(hz, Paint()..color = Colors.white.withValues(alpha: 0.05));
    }
    // bantlar
    final a = ease(t / 1.0);
    final kb = Rect.fromLTRB(x(2), ust, x(2) + (x(k.kucukMax) - x(2)) * a, s.height);
    c.drawRect(kb, Paint()..color = tm.vurgu2.withValues(alpha: 0.22));
    final bb = Rect.fromLTRB(x(k.buyukMin), ust, x(k.buyukMin) + (x(k.buyukMax) - x(k.buyukMin)) * a, s.height);
    c.drawRect(bb, Paint()
      ..shader = ui.Gradient.linear(bb.topCenter, bb.bottomCenter, [tm.vurgu.withValues(alpha: 0.55), tm.vurgu.withValues(alpha: 0.12)]));
    // dip (kum)
    final dip = Path()..moveTo(0, y(p.first.value));
    for (final e in p) {
      dip.lineTo(x(e.key), y(e.value));
    }
    dip
      ..lineTo(s.width, y(p.last.value))
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(dip, Paint()..shader = ui.Gradient.linear(Offset(0, ust), Offset(0, s.height), const [Color(0xFFF0CF96), Color(0xFF8C6A3E)]));
    final rnd = math.Random(3);
    c.save();
    c.clipPath(dip);
    for (var i = 0; i < 260; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * s.width, ust + rnd.nextDouble() * (s.height - ust)), 2 + rnd.nextDouble() * 3,
          Paint()..color = Colors.black.withValues(alpha: 0.08));
    }
    c.restore();
    // kayalık kıyı
    final kaya = Path()
      ..moveTo(0, ust - 70)
      ..lineTo(40, ust - 88)
      ..lineTo(92, ust - 76)
      ..lineTo(128, ust - 52)
      ..lineTo(kiyi - 6, ust - 18)
      ..lineTo(kiyi + 30, ust + 60)
      ..lineTo(kiyi + 10, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(kaya, Paint()..shader = ui.Gradient.linear(Offset(0, ust - 90), Offset(0, s.height), const [Color(0xFF5B5F66), Color(0xFF26292E)]));
    c.drawPath(
        Path()
          ..moveTo(0, ust - 70)
          ..lineTo(40, ust - 88)
          ..lineTo(92, ust - 76)
          ..lineTo(128, ust - 52),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = tm.gunes.withValues(alpha: 0.6));
    // balıkçı: kamışı geri alır (0–0,35 sn), öne savurur (0,35–0,7 sn), sonra bekler
    final geriAl = ease(t / 0.35), savur = Curves.easeInOutCubic.transform(((t - 0.35) / 0.35).clamp(0.0, 1.0));
    final aci0 = -1.05, aciGeri = -2.55, aciOn = -0.55;
    final aci = t < 0.35 ? aci0 + (aciGeri - aci0) * geriAl : aciGeri + (aciOn - aciGeri) * savur;
    final bukum = t < 0.35 ? -0.4 * geriAl : (t < 0.75 ? 0.9 * math.sin(savur * math.pi) : 0.15 * math.sin(t * 3));
    final uc = balikciCiz(c, const Offset(62, ust - 84), 255, aci, bukum, const Color(0xFF12141A), tm.gunes);
    // atış: misina yayı hedefe doğru uzar, sonra suya iner
    final hedef = Offset(x((k.buyukMin + k.buyukMax) / 2), ust);
    final at = ease((t - 0.6) / 0.7);
    if (t > 0.6) {
      final yay = Path()
        ..moveTo(uc.dx, uc.dy)
        ..quadraticBezierTo((uc.dx + hedef.dx) / 2, math.max(40.0, math.min(uc.dy, hedef.dy) - 110), hedef.dx, hedef.dy);
      final m = yay.computeMetrics().first;
      final parca = m.extractPath(0, m.length * at);
      c.drawPath(parca, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.9));
      final yem = m.getTangentForOffset(m.length * at)?.position;
      if (yem != null) c.drawCircle(yem, 7, Paint()..color = tm.vurgu2);
    }
    if (at >= 1) {
      final derin = y(dipte((k.buyukMin + k.buyukMax) / 2) * 0.55);
      final iner = ease((t - 1.3) / 0.5);
      final alt = Offset(hedef.dx, ust + (derin - ust) * iner);
      c.drawLine(hedef, alt, Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 2);
      c.drawCircle(alt, 7, Paint()..color = tm.vurgu2);
      // suya düştüğü yerde halka
      final hr = ((t - 1.3) * 1.4) % 1;
      c.drawOval(Rect.fromCenter(center: hedef, width: 30 + hr * 120, height: 8 + hr * 24), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: (1 - hr) * 0.7));
    }
    // mesafe işaretleri
    for (var mm = 0; mm <= maxX; mm += maxX > 120 ? 40 : 20) {
      final tp = TextPainter(text: TextSpan(text: '$mm m', style: ts(fGovM, 30, Colors.white)), textDirection: TextDirection.ltr)..layout();
      if (x(mm) + tp.width / 2 > s.width - 8) continue;
      tp.paint(c, Offset(x(mm) - tp.width / 2 + (mm == 0 ? 24 : 0), ust - 52));
    }
    // balıklar: günün türleri — büyük bandın ortasında büyük, küçük bantta iki küçük
    final bm = (k.buyukMin + k.buyukMax) / 2;
    final gor = ease((t - 0.3) / 0.5);
    final bo = Offset(x(bm) + math.sin(t * 2) * 30 + (1 - gor) * 120, y(dipte(bm) * 0.6) + math.cos(t * 3) * 10);
    c.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: gor));
    turCiz(c, bo, 230, buyukTur, sola: true, t: t, hale: tm.vurgu);
    final ad = TextPainter(text: TextSpan(text: buyukHarf(buyukTur.ad), style: ts(fBasB, 40, Colors.white)), textDirection: TextDirection.ltr)
      ..layout();
    ad.paint(c, Offset(bo.dx - ad.width / 2, bo.dy + 62));
    c.restore();
    for (var i = 0; i < 2; i++) {
      final km = 2 + (k.kucukMax - 2) * (0.35 + i * 0.35);
      final ko = Offset(x(km) + math.sin(t * 3 + i) * 20, y(dipte(km) * 0.5) + i * 40 + 14);
      turCiz(c, ko, 95, kucukTur, sola: i == 0, t: t + i, hale: tm.vurgu2);
    }
    // bant etiketi
    final et = TextPainter(text: TextSpan(text: 'BÜYÜK BALIK ${k.buyuk}', style: ts(fBasB, 44, tm.vurgu)), textDirection: TextDirection.ltr)
      ..layout();
    final ex = (x(k.buyukMin) + x(k.buyukMax)) / 2 - et.width / 2;
    et.paint(c, Offset(ex.clamp(kiyi + 10, s.width - et.width - 10), ust + 24));
  }

  @override
  bool shouldRepaint(Kesit o) => true;
}

// ------------------------------------------------------------------ sahneler
class Sahne {
  final double sure;
  final Widget Function(double sec) ciz;
  Sahne(this.sure, this.ciz);
}

class Kaynaklar {
  final List<List<Offset>> kara;
  final ui.Image? robot;
  Kaynaklar(this.kara, this.robot);
}

List<Sahne> sahneler(List<MeraGunu> uc, DateTime now, Tema tm, Kaynaklar kn) {
  final en = uc.first;
  final hepsiFirtina = uc.every((m) => m.firtina);
  final turlar = TurStil.sec(en.turler);
  Widget zemin(MeraGunu m, double sec, {double ufuk = 0.6}) => CustomPaint(
      painter: Atmosfer(tm, sec,
          ruzgar: m.r.effectiveWind,
          ruzgarYon: (m.r.windDir ?? 0).toDouble(),
          dalga: m.spot.strait ? 0.15 : m.r.effectiveWave,
          bulut: m.r.cloud ?? 30,
          gun: now,
          ufuk: ufuk));
  final S = <Sahne>[];

  // 1) KANCA: ilk kare dolu ve okunur (kararma yok), satırlar "patlayarak" gelir, sayı sayar
  S.add(Sahne(2.3, (sec) {
    final say = ease((sec - 0.3) / 0.55);
    final s1 = 1.25 - 0.25 * ease(sec / 0.22), s2 = 1.25 - 0.25 * ease((sec - 0.1) / 0.22);
    final mn = (en.k.buyukMin * say).round(), mx = (en.k.buyukMax * say).round();
    return Stack(children: [
      Positioned.fill(child: zemin(en, sec + 2, ufuk: 0.66)),
      Positioned(
        left: 0, right: 0, top: 200,
        child: Center(
            child: cam(Text('${gunAdi(now)} · İSTANBUL', style: ts(fGov, 36, Colors.white, ls: 2)),
                p: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), r: 40)),
      ),
      Positioned(
          left: 40, right: 40, top: 320,
          child: Transform.scale(scale: s1, child: sigdir('BUGÜN BALIK', ts(fBas, 190, Colors.white, h: 1), orta: true))),
      Positioned(
          left: 40, right: 40, top: 505,
          child: Transform.scale(scale: s2, child: sigdir('KAÇ METREDE?', ts(fBas, 190, tm.vurgu, h: 1), orta: true))),
      Positioned(
        left: 40, right: 40, top: 760,
        child: Opacity(
          opacity: ease((sec - 0.25) / 0.2),
          child: Column(children: [
            sigdir(hepsiFirtina ? 'KIYIDAN UZAK DUR' : '$mn–$mx m', ts(fBas, hepsiFirtina ? 150 : 270, Colors.white, h: 1), orta: true),
            const SizedBox(height: 8),
            Text(hepsiFirtina ? 'Rüzgâr ve dalga çok sert' : 'büyük balık · ${en.spot.name}', style: ts(fGov, 58, Colors.white)),
            const SizedBox(height: 22),
            if (!hepsiFirtina)
              Wrap(spacing: 14, children: [
                for (final b in en.turler)
                  cam(Text(b, style: ts(fGov, 40, Colors.white)), p: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), r: 40),
              ]),
          ]),
        ),
      ),
      Positioned(
          left: 0, right: 0, bottom: 300 + math.sin(sec * 7) * 10,
          child: Opacity(
              opacity: ease((sec - 0.9) / 0.3),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Günün en iyi 3 merası', style: ts(fBasB, 64, Colors.white)),
                const SizedBox(width: 10),
                Icon(Icons.keyboard_double_arrow_down, color: tm.vurgu, size: 70),
              ]))),
    ]);
  }));

  // 2) MERALAR
  for (var i = 0; i < uc.length; i++) {
    final m = uc[i];
    S.add(Sahne(2.7, (sec) {
      final g = ease(sec / 0.4);
      final r = m.r;
      Widget olcu(Widget ic, String deger, String ad) => Expanded(
            child: Column(children: [
              SizedBox(height: 70, child: Center(child: ic)),
              const SizedBox(height: 6),
              sigdir(deger, ts(fBas, 62, Colors.white), orta: true),
              Text(ad, style: ts(fGovM, 32, Colors.white.withValues(alpha: 0.85))),
            ]),
          );
      return Stack(children: [
        Positioned.fill(child: zemin(m, sec + i * 4.0)),
        Positioned(
          left: 60, right: 60, top: 190,
          child: Transform.translate(
            offset: Offset((1 - g) * 500, 0),
            child: Opacity(
              opacity: g,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                    decoration: BoxDecoration(color: tm.vurgu, borderRadius: BorderRadius.circular(40)),
                    child: Text('${i + 1}. MERA', style: ts(fBasB, 52, const Color(0xFF14161F), golge: false)),
                  ),
                  const SizedBox(width: 20),
                  Text(buyukHarf(m.spot.side.label), style: ts(fGov, 38, Colors.white, ls: 1.5)),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: 960, child: sigdir(buyukHarf(m.spot.name), ts(fBas, 200, Colors.white, h: 1))),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 60, top: 560, width: 560,
          child: Opacity(
            opacity: ease((sec - 0.2) / 0.35),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BÜYÜK BALIK', style: ts(fGov, 42, Colors.white, ls: 2)),
              sigdir(m.firtina ? 'BUGÜN YOK' : m.k.buyuk, ts(fBas, 210, tm.vurgu, h: 1)),
              const SizedBox(height: 8),
              Text('küçük balık ${m.k.kucuk}', style: ts(fGov, 42, Colors.white)),
              Text('gece ${m.k.gece}', style: ts(fGov, 42, Colors.white)),
            ]),
          ),
        ),
        Positioned(
          right: 60, top: 590, width: 380, height: 290,
          child: Opacity(
            opacity: ease((sec - 0.3) / 0.35),
            child: CustomPaint(painter: Harita(kn.kara, Offset(m.spot.lon, m.spot.lat), sec, tm)),
          ),
        ),
        Positioned(
          left: 60, right: 60, top: 960,
          child: Opacity(
            opacity: ease((sec - 0.45) / 0.35),
            child: cam(
                Row(children: [
                  olcu(Transform.rotate(angle: ((r.windDir ?? 0) + 180) * math.pi / 180, child: const Icon(Icons.navigation, color: Colors.white, size: 66)),
                      '${r.effectiveWind.round()} km/s', r.windFrom.isEmpty ? 'rüzgâr' : kucukHarf(r.windFrom)),
                  olcu(const Icon(Icons.waves, color: Colors.white, size: 66), m.spot.strait ? 'Boğaz' : '${ondalik(r.effectiveWave)} m', 'dalga'),
                  olcu(const Icon(Icons.thermostat, color: Colors.white, size: 66), r.seaC == null ? '—' : '${r.seaC!.round()}°', 'deniz'),
                  olcu(Text('%', style: ts(fBas, 64, tm.vurgu)), '${m.puan}', 'verim'),
                ]),
                p: const EdgeInsets.symmetric(vertical: 26, horizontal: 10)),
          ),
        ),
        Positioned(
          left: 60, right: 60, top: 1290,
          child: Opacity(
            opacity: ease((sec - 0.7) / 0.35),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 30, 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 90, height: 46, child: CustomPaint(painter: _BalikSimge(TurStil.sec(m.turler).$1))),
                  const SizedBox(width: 14),
                  Text(m.k.takim, style: ts(fBasB, 62, const Color(0xFF14161F), golge: false)),
                ]),
              ),
              const SizedBox(height: 22),
              Text(m.k.neden, style: ts(fGovM, 44, Colors.white, h: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ]);
    }));
  }

  // 3) KESİT: olta atışı ve balığın beklediği bant
  S.add(Sahne(3.0, (sec) {
    return Stack(children: [
      Positioned.fill(child: zemin(en, sec + 13, ufuk: 0.3)),
      Positioned(left: 60, right: 60, top: 190, child: sigdir('${buyukHarf(en.spot.name)}: KIYIDAN AÇIĞA', ts(fBas, 110, Colors.white, h: 1))),
      Positioned(
          left: 60, right: 60, top: 320,
          child: Text('Parlak bant: büyük balığın bugün beklediği mesafe', style: ts(fGovM, 42, Colors.white))),
      Positioned(
        left: 30, right: 30, top: 420, height: 900,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: CustomPaint(painter: Kesit(en.info?.profile ?? const [], en.k, tm, sec, turlar.$1, turlar.$2))),
      ),
      Positioned(
        left: 60, right: 60, top: 1370,
        child: Opacity(opacity: ease((sec - 1.5) / 0.4), child: cam(Text(en.hukum, style: ts(fGov, 50, Colors.white, h: 1.2), maxLines: 3))),
      ),
    ]);
  }));

  // 4) ÇAĞRI: uygulamayı ücretsiz indir (Kıyıdabiri robotu, özellikler, mağazalar)
  S.add(Sahne(3.2, (sec) {
    final g = geri(sec / 0.45);
    final nabiz = 1 + 0.05 * math.sin(sec * 7);
    Widget ozellik(String m, double gecikme) => Opacity(
        opacity: ease((sec - gecikme) / 0.3),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 52),
            const SizedBox(width: 16),
            Text(m, style: ts(fGov, 48, Colors.white)),
          ]),
        ));
    Widget magaza(IconData ic, String ad) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFF14161F), borderRadius: BorderRadius.circular(22)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, color: Colors.white, size: 54),
            const SizedBox(width: 12),
            Text(ad, style: ts(fBasB, 50, Colors.white, golge: false)),
          ]),
        );
    return Stack(children: [
      Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tm.cta)))),
      Positioned.fill(child: Opacity(opacity: 0.3, child: zemin(en, sec + 20, ufuk: 0.8))),
      if (kn.robot != null)
        Positioned(
          left: 0, right: 0, top: 150 + math.sin(sec * 4) * 12,
          child: Center(child: Transform.scale(scale: g, child: SizedBox(width: 300, height: 300, child: RawImage(image: kn.robot, fit: BoxFit.contain)))),
        ),
      Positioned(
        left: 60, right: 60, top: 480,
        child: Transform.scale(
          scale: 0.85 + 0.15 * g,
          child: Column(children: [
            sigdir('SENİN MERAN', ts(fBas, 150, Colors.white, h: 1), orta: true),
            sigdir('BUGÜN NE DURUMDA?', ts(fBas, 120, const Color(0xFF14161F), h: 1, golge: false), orta: true),
            const SizedBox(height: 36),
            ozellik('Balık bugün kaç metrede', 0.35),
            ozellik('Canlı rüzgâr, dalga ve takım', 0.5),
            ozellik('Kıyıdabiri asistanına sor', 0.65),
            const SizedBox(height: 30),
            Transform.scale(
              scale: nabiz,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 26),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(70), boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10)),
                ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('ÜCRETSİZ İNDİR', style: ts(fBas, 84, const Color(0xFF14161F), golge: false)),
                  const SizedBox(width: 14),
                  const Icon(Icons.download_rounded, color: Color(0xFF14161F), size: 80),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            Text('Link profilde · KıyıdanAv', style: ts(fBasB, 56, Colors.white)),
            const SizedBox(height: 26),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              magaza(Icons.android, 'Google Play'),
              const SizedBox(width: 18),
              magaza(Icons.apple, 'App Store'),
            ]),
          ]),
        ),
      ),
    ]);
  }));
  return S;
}

/// t anındaki kare. İlk sahnede giriş kararması yok; aralarda 0,2 sn beyaz parlama ile geçiş
Widget kare(List<Sahne> S, double t) {
  var a = 0.0;
  for (var i = 0; i < S.length; i++) {
    final s = S[i];
    if (t < a + s.sure || i == S.length - 1) {
      final sec = (t - a).clamp(0.0, s.sure);
      final gecis = i == 0 ? 0.0 : (1 - sec / 0.2).clamp(0.0, 1.0);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: rw,
          height: rh,
          child: Stack(children: [
            Positioned.fill(child: s.ciz(sec)),
            if (gecis > 0) Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: gecis * 0.7))),
            Positioned(right: 50, top: 70, child: Text('KıyıdanAv', style: ts('Armata', 40, Colors.white.withValues(alpha: 0.9)))),
            if (i < S.length - 1)
              Positioned(
                left: 50, top: 62,
                child: cam(
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_iphone, color: Colors.white, size: 34),
                      const SizedBox(width: 8),
                      Text('Ücretsiz uygulama · link profilde', style: ts(fGov, 30, Colors.white)),
                    ]),
                    p: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), r: 30, koyu: 0.35),
              ),
          ]),
        ),
      );
    }
    a += s.sure;
  }
  return const SizedBox();
}
