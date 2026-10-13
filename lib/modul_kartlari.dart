import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'balik_bul.dart';
import 'catches.dart';
import 'mera.dart';
import 'modul_veri.dart';
import 'moduller.dart';
import 'olcum_sheet.dart';
import 'olcum_yorum.dart';
import 'sea.dart';
import 'solunar.dart';
import 'theme.dart';

/// Kart şablonunun renkleri (panel → Tasarım ve şablon + modülün kendi rengi/şablonu)
class ModulStil {
  final bool koyu;
  final Color yazi;
  final Color soluk;
  final Color vurgu;
  final Color cizgi;
  final Color cip;
  final ModulTema tema;
  const ModulStil(
      {required this.koyu,
      required this.yazi,
      required this.soluk,
      required this.vurgu,
      required this.cizgi,
      required this.cip,
      required this.tema});

  Color get iyi => Color(tema.iyi);
  Color get orta => Color(tema.orta);
  Color get zayif => Color(tema.zayif);
  Color ton(Ton t) => t == Ton.iyi ? iyi : (t == Ton.orta ? orta : zayif);

  TextStyle get metin => TextStyle(color: yazi, fontSize: 13.5, height: 1.4);
  TextStyle get kucuk => TextStyle(color: soluk, fontSize: 11.5, height: 1.35);
  TextStyle get kalin => TextStyle(color: yazi, fontSize: 14, fontWeight: FontWeight.w800);
}

/// Bütün modül kartlarının ortak kabuğu
class ModulKart extends StatelessWidget {
  final ModulCfg m;
  final IconData ikon;
  final String baslik;
  final String alt;
  final Widget Function(ModulStil s) govde;
  final VoidCallback? onTap;

  /// true: paneldeki başlık/alt başlık yerine kartın kendi başlığı (ör. mera adıyla istatistik)
  final bool kendiBaslik;
  const ModulKart(
      {super.key,
      required this.m,
      required this.ikon,
      required this.baslik,
      this.alt = '',
      required this.govde,
      this.onTap,
      this.kendiBaslik = false});

  @override
  Widget build(BuildContext context) {
    final t = Moduller.tema;
    final sablon = m.sablon.isNotEmpty ? m.sablon : t.sablon;
    final vurgu = Color(ModulTema.renk(m.renk) ?? t.vurgu);
    final koyu = sablon == 'derin';
    final s = ModulStil(
      koyu: koyu,
      yazi: koyu ? Colors.white : const Color(0xFF1E2228),
      soluk: koyu ? const Color(0xFFBFD6D1) : const Color(0xFF6B6A60),
      vurgu: vurgu,
      cizgi: koyu ? const Color(0x24FFFFFF) : const Color(0x14000000),
      cip: koyu ? const Color(0x1FFFFFFF) : const Color(0x0D000000),
      tema: t,
    );
    final r = BorderRadius.circular(t.kose);
    BoxDecoration dek;
    switch (sablon) {
      case 'acik':
        dek = BoxDecoration(color: Colors.white, borderRadius: r, border: Border.all(color: const Color(0xFFE2DFD4)));
        break;
      case 'cam':
        dek = BoxDecoration(
            color: const Color(0xCCFFFFFF), borderRadius: r, border: Border.all(color: const Color(0xB3FFFFFF)));
        break;
      case 'serit':
        dek = BoxDecoration(
            color: Colors.white,
            borderRadius: r,
            border: Border(left: BorderSide(color: vurgu, width: 6)),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]);
        break;
      default:
        dek = BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(t.ana), Color(t.ana2)]));
    }
    final ic = t.kompakt ? 11.0 : 16.0;
    final kutu = Container(
      decoration: dek,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(ic),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: vurgu, borderRadius: BorderRadius.circular(9)),
            child: Icon(ikon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.baslik.isNotEmpty && !kendiBaslik ? m.baslik : baslik,
                  style: TextStyle(color: s.yazi, fontSize: 15.5, fontWeight: FontWeight.w800, fontFamily: Tide.font)),
              if ((m.alt.isNotEmpty && !kendiBaslik ? m.alt : alt).isNotEmpty)
                Text(m.alt.isNotEmpty && !kendiBaslik ? m.alt : alt, style: s.kucuk),
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: s.soluk),
          if (m.test)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE0A526), borderRadius: BorderRadius.circular(6)),
              child: const Text('TEST', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ]),
        SizedBox(height: t.kompakt ? 8 : 12),
        govde(s),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: onTap == null
          ? kutu
          : Material(color: Colors.transparent, child: InkWell(borderRadius: r, onTap: onTap, child: kutu)),
    );
  }
}

Widget _cip(ModulStil s, String t, {bool secili = false, Color? renk}) => Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: secili ? s.vurgu : (renk ?? s.cip), borderRadius: BorderRadius.circular(9)),
      child: Text(t, style: TextStyle(color: secili || renk != null ? Colors.white : s.yazi, fontSize: 12, fontWeight: FontWeight.w600)),
    );

Widget _etiket(ModulStil s, String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
      child: Text(t.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
    );

String _ss(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// =====================================================================
// Raporun altındaki modül alanı
// =====================================================================
/// Raporun üstü (yalnız "Raporun en üstü" seçilen mesafe kartı) ya da altı
enum ModulKonum { ust, alt }

class ModulAlani extends StatelessWidget {
  final SpotForecast f;
  final SatInfo? sat;
  final DateTime now;
  final bool uye;
  final ModulKonum konum;
  const ModulAlani({super.key, required this.f, this.sat, required this.now, required this.uye, this.konum = ModulKonum.alt});

  static const kimlikler = [
    'mesafe_karti', 'kiyi_yonu', 'solunar', 'berraklik', 'termal', 'deniz_seviyesi', 'akinti_yonu', 'goc',
  ];

  @override
  Widget build(BuildContext context) {
    bool ustte(ModulCfg m) => m.id == 'mesafe_karti' && m.s('konum') == 'Raporun en üstü';
    final mods = Moduller.sirali(kimlikler, uye: uye).where((m) => konum == ModulKonum.ust ? ustte(m) : !ustte(m)).toList();
    if (mods.isEmpty) return const SizedBox.shrink();
    final ekGerekli = mods.any((m) => m.id == 'kiyi_yonu' || m.id == 'deniz_seviyesi' || m.id == 'akinti_yonu');
    return FutureBuilder<EkDeniz?>(
      future: ekGerekli ? EkDeniz.of(f.spot) : Future.value(null),
      builder: (context, snap) {
        final ek = snap.data;
        final kartlar = <Widget>[];
        for (final m in mods) {
          final w = _kart(context, m, ek);
          if (w != null) kartlar.add(w);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kartlar);
      },
    );
  }

  Widget? _kart(BuildContext context, ModulCfg m, EkDeniz? ek) {
    switch (m.id) {
      case 'mesafe_karti':
        return MesafeKarti(m: m, f: f, sat: sat, now: now);
      case 'kiyi_yonu':
        return KiyiYonuKarti(m: m, f: f, ek: ek);
      case 'solunar':
        return SolunarKarti(m: m, f: f, now: now);
      case 'berraklik':
        return sat?.kd490 == null ? null : BerraklikKarti(m: m, kd: sat!.kd490!);
      case 'termal':
        return (sat?.termalFark == null || sat!.termalFark! < m.n('esik', 0.5)) ? null : TermalKarti(m: m, sat: sat!);
      case 'deniz_seviyesi':
        return ek == null ? null : DenizSeviyesiKarti(m: m, ek: ek, now: now, spot: f.spot);
      case 'akinti_yonu':
        return AkintiKarti(m: m, f: f, ek: ek);
      case 'goc':
        return m.l('kayitlar').isEmpty ? null : GocKarti(m: m);
    }
    return null;
  }
}

// =====================================================================
// 1) Bugün balık kaç metrede?
// =====================================================================
class MesafeKarti extends StatefulWidget {
  final ModulCfg m;
  final SpotForecast f;
  final SatInfo? sat;
  final DateTime now;
  const MesafeKarti({super.key, required this.m, required this.f, this.sat, required this.now});

  @override
  State<MesafeKarti> createState() => _MesafeKartiState();
}

class _MesafeKartiState extends State<MesafeKarti> {
  int _secili = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.m, f = widget.f, r = f.now, sat = widget.sat;
    final girdiler = <MesafeGirdi>[
      MesafeGirdi(Yorum.basinc(r.pressure, f.pressureTrend), m.n('agirlikBasinc', 4)),
      if (r.cloud != null) MesafeGirdi(Yorum.bulut(r.cloud!), m.n('agirlikIsik', 3)),
      if (!r.strait && r.waveM != null) MesafeGirdi(Yorum.dalga(r.effectiveWave, false), m.n('agirlikDalga', 3)),
      if (sat?.sst != null) MesafeGirdi(Yorum.uyduSst(sat!.sst!, sat.sstChange5d, widget.now.month), m.n('agirlikSu', 2)),
      if (sat?.chl != null) MesafeGirdi(Yorum.klorofil(sat!.chl!, sat.chlChangePct), m.n('agirlikKlorofil', 2)),
    ];
    final h = mesafeHukmu(girdiler);
    if (h == null) return const SizedBox.shrink();
    final dis = m.l('disiplinler');
    if (_secili >= dis.length) _secili = 0;
    final d = dis.isEmpty ? null : dis[_secili];
    // Seçili disiplinin atış bandıyla bugünün bandının kesişimi
    String? oneriBant;
    if (d != null) {
      final dmin = (d['min'] is num ? (d['min'] as num).toDouble() : 0.0);
      final dmax = (d['max'] is num ? (d['max'] as num).toDouble() : 200.0);
      final a = math.max(dmin, h.bant.min), b = math.min(dmax, h.bant.max);
      oneriBant = a <= b
          ? 'Bugün ${a.round()}–${b.round()} m arasını tara'
          : (dmax < h.bant.min ? 'Balık bu disiplinin menzilinin ötesinde — en uzak atışı dene' : 'Balık yakında — kıyı dibini tara');
    }
    return ModulKart(
      m: m,
      ikon: Icons.my_location,
      baslik: 'Bugün balık kaç metrede?',
      alt: 'Tüm ölçümlerin ortak yorumu',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${h.bant.min.round()}–${h.bant.max.round()} m',
              style: TextStyle(color: s.yazi, fontSize: 30, fontWeight: FontWeight.w800, fontFamily: Tide.font)),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: _etiket(s, h.etiket, s.vurgu)),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(children: [
            Container(height: 10, decoration: BoxDecoration(color: s.cizgi, borderRadius: BorderRadius.circular(5))),
            Positioned(
              left: w * h.bant.min / 200,
              width: math.max(6, w * (h.bant.max - h.bant.min) / 200),
              top: 0,
              bottom: 0,
              child: Container(decoration: BoxDecoration(color: s.vurgu, borderRadius: BorderRadius.circular(5))),
            ),
          ]);
        }),
        const SizedBox(height: 2),
        Row(children: [Text('Kıyı', style: s.kucuk), const Spacer(), Text('100 m', style: s.kucuk), const Spacer(), Text('200 m', style: s.kucuk)]),
        if (h.neden.isNotEmpty) ...[const SizedBox(height: 8), Text(h.neden, style: s.metin)],
        if (dis.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(children: [
            for (var i = 0; i < dis.length; i++)
              GestureDetector(
                onTap: () => setState(() => _secili = i),
                child: _cip(s, '${dis[i]['ad'] ?? ''}', secili: i == _secili),
              ),
          ]),
        ],
        if (d != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['ad'] ?? ''} için öneri', style: s.kucuk),
              const SizedBox(height: 2),
              if ('${d['yem'] ?? ''}'.isNotEmpty) Text('${d['yem']}', style: s.kalin),
              if (oneriBant != null) Text(oneriBant, style: s.metin),
            ]),
          ),
        if (m.b('urunButon', true) && d != null && '${d['ara'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: s.vurgu),
              onPressed: () => modulUrunAc(context, '${d['ara']}', '${d['ad']} için ürünler'),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Önerilen ürünleri gör'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Ürün araması açar (bait_card'daki arama ekranı) — report_screen bu işlevi bağlar
void Function(BuildContext context, String ara, String baslik) modulUrunAc = (_, __, ___) {};

// =====================================================================
// 2) Kıyı yönü + rüzgâr/dalga yönü
// =====================================================================
class KiyiYonuKarti extends StatelessWidget {
  final ModulCfg m;
  final SpotForecast f;
  final EkDeniz? ek;
  const KiyiYonuKarti({super.key, required this.m, required this.f, this.ek});

  @override
  Widget build(BuildContext context) {
    final satir = m.l('meralar').where((e) => '${e['mera'] ?? ''}'.trim().toLowerCase() == f.spot.name.toLowerCase()).toList();
    if (satir.isEmpty) return const SizedBox.shrink();
    final kiyi = satir.first['yon'] is num ? (satir.first['yon'] as num).toDouble() : double.tryParse('${satir.first['yon']}');
    final rz = f.now.windDir?.toDouble();
    if (kiyi == null || rz == null) return const SizedBox.shrink();
    final aci = m.n('aci', 60);
    final vurur = kiyiyaVuruyor(kiyi, rz, aci: aci);
    final esiyor = kiyidanEsiyor(kiyi, rz, aci: aci);
    final not = '${satir.first['not'] ?? ''}';
    return ModulKart(
      m: m,
      ikon: Icons.explore_outlined,
      baslik: 'Rüzgâr ve kıyı',
      alt: 'Yem balığı nereye itiliyor?',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (m.b('ok', true))
            SizedBox(width: 104, height: 104, child: CustomPaint(painter: _PusulaPainter(kiyi, rz, ek?.dalgaYon, s))),
          if (m.b('ok', true)) const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.spot.name, style: s.kalin),
              Text('Kıyı ${yonE(yonAdi(kiyi))} bakıyor · rüzgâr ${f.now.windFrom} (${rz.round()}°)', style: s.kucuk),
              const SizedBox(height: 6),
              _etiket(s, vurur ? 'Rüzgâr kıyıya vuruyor' : (esiyor ? 'Rüzgâr kıyıdan esiyor' : 'Rüzgâr kıyıya paralel'),
                  vurur ? s.iyi : (esiyor ? s.orta : s.soluk)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          vurur
              ? 'Yem balığı ve köpük kıyıya itiliyor — levrek ve lüfer yakında. Köpük hattını ve rüzgârın vurduğu burunları tara.'
              : (esiyor
                  ? 'Yüzey suyu açığa kayıyor; kıyıda su berraklaşır ve soğuyabilir. Balık derinde — uzun atış, dibe yakın sunum.'
                  : 'Rüzgâr kıyı boyunca akıntı yapar; yemi akıntının yukarısına at, doğal sürüklensin.'),
          style: s.metin,
        ),
        if (m.b('dalgaYonu', true) && ek?.dalgaYon != null) ...[
          const SizedBox(height: 6),
          Text('🌊 Dalga ${yonDen(yonAdi(ek!.dalgaYon!))} geliyor; kıyıya ${aciFarki(kiyi, ek!.dalgaYon!).round()}° açıyla vuruyor.',
              style: s.kucuk),
        ],
        if (not.isNotEmpty) ...[const SizedBox(height: 4), Text(not, style: s.kucuk)],
      ]),
    );
  }
}

class _PusulaPainter extends CustomPainter {
  final double kiyi;
  final double ruzgar;
  final double? dalga;
  final ModulStil s;
  _PusulaPainter(this.kiyi, this.ruzgar, this.dalga, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..color = s.cizgi
      ..strokeWidth = 2);
    final tp = TextPainter(
        text: TextSpan(text: 'K', style: TextStyle(color: s.soluk, fontSize: 10, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r + 2));
    Offset uc(double deg, double uz) => Offset(c.dx + uz * math.sin(deg * math.pi / 180), c.dy - uz * math.cos(deg * math.pi / 180));
    // Kıyının baktığı yön (deniz tarafı)
    canvas.drawLine(c, uc(kiyi, r * .85), Paint()
      ..color = s.yazi
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    // Rüzgârın gittiği yön (geldiği yönün tersi)
    final git = (ruzgar + 180) % 360;
    final p = Paint()
      ..color = s.vurgu
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(uc(ruzgar, r * .8), uc(git, r * .8), p);
    final uc1 = uc(git, r * .8);
    canvas.drawLine(uc1, Offset(uc1.dx + 8 * math.sin((git + 150) * math.pi / 180), uc1.dy - 8 * math.cos((git + 150) * math.pi / 180)), p);
    canvas.drawLine(uc1, Offset(uc1.dx + 8 * math.sin((git - 150) * math.pi / 180), uc1.dy - 8 * math.cos((git - 150) * math.pi / 180)), p);
    if (dalga != null) {
      canvas.drawCircle(uc(dalga!, r * .95), 4, Paint()..color = const Color(0xFF4FC3F7));
    }
  }

  @override
  bool shouldRepaint(_PusulaPainter o) => o.kiyi != kiyi || o.ruzgar != ruzgar || o.dalga != dalga;
}

// =====================================================================
// 3) Kesit 0–200 m + şev
// =====================================================================
class KesitKarti extends StatelessWidget {
  final ModulCfg m;
  final Spot spot;
  final MeraInfo info;
  const KesitKarti({super.key, required this.m, required this.spot, required this.info});

  @override
  Widget build(BuildContext context) {
    final sev = sevBul(info.profile, esik: m.n('sevEsik', 5));
    return ModulKart(
      m: m,
      ikon: Icons.layers_outlined,
      baslik: 'Kıyıdan açığa kesit',
      alt: info.dip.isNotEmpty ? info.dip : 'Şev nerede?',
      onTap: () => showMeraSheet(context, spot, info),
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (info.profile.length >= 2 && m.s('grafik', 'Profil çizimi') == 'Profil çizimi')
          SizedBox(height: 130, child: CustomPaint(painter: _KesitPainter(info.profile, sev, m.b('disiplinIsaret', true), s)))
        else
          for (final e in info.profile)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 74, child: Text('${e.key} m', style: s.kucuk)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: (e.value / 30).clamp(0.05, 1.0), minHeight: 8, color: s.vurgu, backgroundColor: s.cizgi),
                  ),
                ),
                SizedBox(width: 50, child: Text('~${e.value.toStringAsFixed(e.value < 10 ? 1 : 0)} m', textAlign: TextAlign.right, style: s.kalin)),
              ]),
            ),
        const SizedBox(height: 8),
        Text(
          sev != null
              ? 'Şev ${sev.bas}–${sev.son} m arasında (50 m\'de ~${sev.artis.round()} m derinleşiyor). Jig ve surf için hedef bant; avcı balık şev kenarında bekler.'
              : 'Belirgin bir şev yok; dip yavaş derinleşiyor. Balık dağınık — farklı mesafeleri tara.',
          style: s.metin,
        ),
        if (m.b('disiplinIsaret', true)) Text('Mavi: LRF bandı (2–20 m) · Turuncu: spin/jig bandı (10–50 m)', style: s.kucuk),
        if (info.note.isNotEmpty) ...[const SizedBox(height: 4), Text(info.note, style: s.kucuk)],
      ]),
    );
  }
}

class _KesitPainter extends CustomPainter {
  final List<MapEntry<int, double>> p;
  final Sev? sev;
  final bool bantlar;
  final ModulStil s;
  _KesitPainter(List<MapEntry<int, double>> profil, this.sev, this.bantlar, this.s) : p = ([...profil]..sort((a, b) => a.key.compareTo(b.key)));

  @override
  void paint(Canvas canvas, Size size) {
    final mx = math.max(200, p.last.key).toDouble();
    final md = math.max(5.0, p.map((e) => e.value).reduce(math.max));
    const ust = 16.0;
    double x(num m) => 4 + m / mx * (size.width - 8);
    double y(double d) => ust + d / md * (size.height - ust - 14);
    if (bantlar) {
      canvas.drawRRect(RRect.fromLTRBR(x(2), 2, x(20), 8, const Radius.circular(3)), Paint()..color = const Color(0xFF4FC3F7));
      canvas.drawRRect(RRect.fromLTRBR(x(10), 10, x(50), 15, const Radius.circular(3)), Paint()..color = const Color(0xD9FFB74D));
    }
    final yol = Path()..moveTo(x(0), y(0));
    for (final e in p) {
      yol.lineTo(x(e.key), y(e.value));
    }
    final dolgu = Path.from(yol)
      ..lineTo(x(p.last.key), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(dolgu, Paint()..color = s.vurgu.withAlpha(60));
    canvas.drawPath(yol, Paint()
      ..color = s.vurgu
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    final ts = TextStyle(color: s.yazi, fontSize: 9.5, fontWeight: FontWeight.w700);
    for (final e in p) {
      final tp = TextPainter(text: TextSpan(text: '${e.value.round()}m', style: ts), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(math.min(size.width - tp.width, math.max(0, x(e.key) - tp.width / 2)), y(e.value) - 13));
    }
    if (sev != null) {
      final sx = x(sev!.son);
      final paint = Paint()
        ..color = s.zayif
        ..strokeWidth = 1.5;
      for (var yy = ust; yy < size.height; yy += 7) {
        canvas.drawLine(Offset(sx, yy), Offset(sx, yy + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KesitPainter o) => true;
}

// =====================================================================
// 4) Su berraklığı
// =====================================================================
class BerraklikKarti extends StatelessWidget {
  final ModulCfg m;
  final double kd;
  const BerraklikKarti({super.key, required this.m, required this.kd});

  @override
  Widget build(BuildContext context) {
    final c = berraklikSinifi(kd, berrak: m.n('berrak', 0.08), bulanik: m.n('bulanik', 0.25));
    return ModulKart(
      m: m,
      ikon: Icons.water_drop_outlined,
      baslik: 'Su berraklığı',
      alt: 'Uydudan görüş mesafesi',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _kutu(s, 'Durum', berraklikAd[c])),
          const SizedBox(width: 8),
          Expanded(child: _kutu(s, 'Görüş (yaklaşık)', '~${gorusMetre(kd).toStringAsFixed(gorusMetre(kd) < 10 ? 1 : 0)} m')),
        ]),
        const SizedBox(height: 8),
        Text(berraklikOneri[c], style: s.metin),
        if (m.b('renkOnerisi', true)) ...[
          const SizedBox(height: 8),
          Wrap(children: [
            for (final (ad, renk) in berraklikRenkler[c])
              Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(renk), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 5),
                  Text(ad, style: TextStyle(color: s.yazi, fontSize: 12)),
                ]),
              ),
          ]),
        ],
        Text('Kd490 = ${kd.toStringAsFixed(3)} m⁻¹ · NOAA VIIRS uydusu, mera çevresi ortalaması', style: s.kucuk),
      ]),
    );
  }
}

Widget _kutu(ModulStil s, String k, String v) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: s.kucuk),
        Text(v, style: TextStyle(color: s.yazi, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );

// =====================================================================
// 5) Solunar saatleri
// =====================================================================
class SolunarKarti extends StatelessWidget {
  final ModulCfg m;
  final SpotForecast f;
  final DateTime now;
  const SolunarKarti({super.key, required this.m, required this.f, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = solunar(now, f.spot.lat, f.spot.lon, buyukSaat: m.n('buyuk', 2), kucukSaat: m.n('kucuk', 1));
    final isik = geceAydinligi(Moon.illumination(now), f.now.cloud);
    return ModulKart(
      m: m,
      ikon: Icons.nightlight_round,
      baslik: 'Solunar av saatleri',
      alt: 'Ayın konumuna göre',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (m.b('zamanCizgisi', true)) ...[
          SizedBox(height: 30, child: CustomPaint(painter: _ZamanPainter(p, now, s))),
          const SizedBox(height: 2),
          Row(children: [
            for (final t in ['00', '06', '12', '18', '24']) ...[Text(t, style: s.kucuk), if (t != '24') const Spacer()],
          ]),
          const SizedBox(height: 6),
        ],
        for (final x in p)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(x.buyuk ? '🌕' : '🌗', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text('${x.buyuk ? 'Büyük' : 'Küçük'} periyot · ${x.ad}', style: s.metin)),
              Text('${_ss(x.bas)}–${_ss(x.son)}',
                  style: TextStyle(
                      color: (now.isAfter(x.bas) && now.isBefore(x.son)) ? s.vurgu : s.yazi, fontWeight: FontWeight.w800)),
            ]),
          ),
        if (m.b('geceIsik', true))
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gece aydınlığı', style: s.kucuk),
              Text(geceAydinligiAd(isik), style: s.kalin),
              Text(geceAydinligiOneri(isik), style: s.kucuk),
            ]),
          ),
        const SizedBox(height: 4),
        Text('Büyük periyotlar ay tepedeyken ve ayak altındayken, küçükler ay doğup batarken. Gün doğumu/batımıyla çakışan periyot en verimlisidir.',
            style: s.kucuk),
      ]),
    );
  }
}

class _ZamanPainter extends CustomPainter {
  final List<SolunarPeriyot> p;
  final DateTime now;
  final ModulStil s;
  _ZamanPainter(this.p, this.now, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), Paint()..color = s.cip);
    final gun = DateTime(now.year, now.month, now.day);
    double x(DateTime t) => (t.difference(gun).inMinutes / 1440).clamp(0.0, 1.0) * size.width;
    for (final e in p) {
      final r = RRect.fromLTRBR(x(e.bas), e.buyuk ? 2 : 8, x(e.son), size.height - (e.buyuk ? 2 : 8), const Radius.circular(5));
      canvas.drawRRect(r, Paint()..color = e.buyuk ? s.vurgu : s.vurgu.withAlpha(150));
    }
    final nx = x(now);
    canvas.drawLine(Offset(nx, 0), Offset(nx, size.height), Paint()
      ..color = s.yazi
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ZamanPainter o) => true;
}

// =====================================================================
// 6) Termal cephe
// =====================================================================
class TermalKarti extends StatelessWidget {
  final ModulCfg m;
  final SatInfo sat;
  const TermalKarti({super.key, required this.m, required this.sat});

  @override
  Widget build(BuildContext context) {
    final fark = sat.termalFark!;
    return ModulKart(
      m: m,
      ikon: Icons.thermostat_auto,
      baslik: 'Sıcak–soğuk su sınırı',
      alt: 'Uydudan su sıcaklığı haritası',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (m.b('harita', true))
          Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFF2B6CB0), Color(0xFF4FC3F7), Color(0xFFF6AD55), Color(0xFFE53E3E)]),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Text('${sat.termalSoguk?.toStringAsFixed(1) ?? '-'}° ${sat.termalSogukYon}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${sat.termalSicak?.toStringAsFixed(1) ?? '-'}° ${sat.termalSicakYon}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
            '~9 km içinde ${fark.toStringAsFixed(1)}°C fark var: sıcak su ${yonDe(sat.termalSicakYon)}, soğuk su ${yonDe(sat.termalSogukYon)}. '
            'Palamut ve lüfer bu sınırda yem balığını sıkıştırır; sınıra yakın burun ve mendirekleri dene.',
            style: s.metin),
        Text('NOAA MUR deniz suyu sıcaklığı (1 km), son gün', style: s.kucuk),
      ]),
    );
  }
}

// =====================================================================
// 7) Deniz seviyesi
// =====================================================================
class DenizSeviyesiKarti extends StatelessWidget {
  final ModulCfg m;
  final EkDeniz ek;
  final DateTime now;
  final Spot spot;
  const DenizSeviyesiKarti({super.key, required this.m, required this.ek, required this.now, required this.spot});

  @override
  Widget build(BuildContext context) {
    final bolge = m.s('bolgeler', 'Tüm bölgeler');
    if (bolge == 'Yalnız Ege ve Çanakkale' && spot.side != Side.ege && spot.side != Side.guneyMarmara) return const SizedBox.shrink();
    final d = seviyeDegisim(ek.seviyeZaman, ek.seviye, now, saat: 12);
    if (d == null || d.cm.abs() < m.n('esik', 10)) return const SizedBox.shrink();
    final yuk = d.cm > 0;
    final i0 = ek.seviyeZaman.indexWhere((t) => !t.isBefore(DateTime(now.year, now.month, now.day, now.hour)));
    final seri = i0 < 0 ? <double?>[] : ek.seviye.sublist(i0, math.min(ek.seviye.length, i0 + 13));
    return ModulKart(
      m: m,
      ikon: Icons.waves,
      baslik: 'Su seviyesi',
      alt: 'Yükselen su = balık sığda',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (seri.whereType<double>().length >= 3) SizedBox(height: 60, child: CustomPaint(painter: _SeriPainter(seri, s))),
        const SizedBox(height: 6),
        Text('Su ${d.cm.abs().round()} cm ${yuk ? 'yükseliyor' : 'alçalıyor'} (${_ss(d.bas)}–${_ss(d.son)}).', style: s.kalin),
        Text(
            yuk
                ? 'Yükselen su balığı sığa ve kıyıya çeker; kumsal ve sığ kayalıkta yakın atış yap.'
                : 'Alçalan su balığı açığa ve kanallara çeker; şev kenarına ve derin noktalara at.',
            style: s.metin),
        Text('Open-Meteo deniz modeli (gelgit + rüzgâr kabarması)', style: s.kucuk),
      ]),
    );
  }
}

class _SeriPainter extends CustomPainter {
  final List<double?> v;
  final ModulStil s;
  _SeriPainter(this.v, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final d = v.whereType<double>().toList();
    final mn = d.reduce(math.min), mx = d.reduce(math.max);
    final ar = math.max(0.02, mx - mn);
    final yol = Path();
    var ilk = true;
    for (var i = 0; i < v.length; i++) {
      final y = v[i];
      if (y == null) continue;
      final o = Offset(i / math.max(1, v.length - 1) * size.width, size.height - 4 - (y - mn) / ar * (size.height - 8));
      if (ilk) {
        yol.moveTo(o.dx, o.dy);
        ilk = false;
      } else {
        yol.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(yol, Paint()
      ..color = s.vurgu
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_SeriPainter o) => true;
}

// =====================================================================
// 8) Akıntı yönü + akıntı cepleri
// =====================================================================
class AkintiKarti extends StatelessWidget {
  final ModulCfg m;
  final SpotForecast f;
  final EkDeniz? ek;
  const AkintiKarti({super.key, required this.m, required this.f, this.ek});

  @override
  Widget build(BuildContext context) {
    final cep = m.l('cepler').where((e) => '${e['mera'] ?? ''}'.trim().toLowerCase() == f.spot.name.toLowerCase()).toList();
    final yon = ek?.akintiYon;
    final hiz = ek?.akintiHiz ?? f.now.currentKmh;
    if (yon == null && cep.isEmpty) return const SizedBox.shrink();
    return ModulKart(
      m: m,
      ikon: Icons.swap_calls,
      baslik: 'Akıntı',
      alt: 'Yön ve akıntı cepleri',
      govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (yon != null)
          Row(children: [
            if (m.b('ok', true))
              Transform.rotate(angle: yon * math.pi / 180, child: Icon(Icons.navigation, color: s.vurgu, size: 40)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${hiz == null ? '' : '${hiz.toStringAsFixed(1)} km/s · '}${yonE(yonAdi(yon))} akıyor', style: s.kalin),
                Text('Yemi akıntının yukarısına at; doğal sürüklensin.', style: s.kucuk),
              ]),
            ),
          ]),
        for (final c in cep)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: s.cip, borderRadius: BorderRadius.circular(10)),
            child: Text('🌀 ${c['not'] ?? ''}', style: s.metin),
          ),
      ]),
    );
  }
}

// =====================================================================
// 9) Göç takvimi
// =====================================================================
class GocKarti extends StatelessWidget {
  final ModulCfg m;
  const GocKarti({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final k = m.l('kayitlar');
    return ModulKart(
      m: m,
      ikon: Icons.timeline,
      baslik: 'Göç takvimi',
      alt: 'Sürüler şu an nerede?',
      govde: (s) {
        Color renk(String d) => d == 'Burada' ? s.iyi : (d == 'Geliyor' ? s.orta : s.soluk);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < k.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: s.cizgi))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${k[i]['tur'] ?? ''}', style: s.kalin),
                    Text([k[i]['bolge'], k[i]['not']].where((e) => '${e ?? ''}'.isNotEmpty).join(' · '), style: s.kucuk),
                  ]),
                ),
                _etiket(s, '${k[i]['durum'] ?? ''}', renk('${k[i]['durum'] ?? ''}')),
              ]),
            ),
        ]);
      },
    );
  }
}

// =====================================================================
// 10) Av istatistiği (bildirime mesafe/derinlik modülü)
// =====================================================================
class AvIstatKarti extends StatelessWidget {
  final ModulCfg m;
  final Spot spot;
  const AvIstatKarti({super.key, required this.m, required this.spot});

  @override
  Widget build(BuildContext context) {
    if (!m.b('istatistik', true)) return const SizedBox.shrink();
    return FutureBuilder<List<AvIstat>>(
      future: AvIstat.of(spot.name),
      builder: (context, snap) {
        final enAz = m.n('enAz', 10).round();
        final liste = (snap.data ?? const <AvIstat>[]).where((e) => e.n >= enAz).toList();
        if (liste.isEmpty) return const SizedBox.shrink();
        return ModulKart(
          m: m,
          ikon: Icons.insights_outlined,
          baslik: '${spot.name}: balık kaç metrede tutuluyor?',
          alt: 'Üyelerin onaylı bildirimlerinden',
          kendiBaslik: true,
          govde: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final e in liste)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(e.balik, style: s.kalin)),
                  Text([e.mesafe, e.derinlik, e.saat].where((x) => x.isNotEmpty).join(' · '), style: s.metin),
                ]),
              ),
            Text('${liste.fold<int>(0, (a, b) => a + b.n)} bildirim · son 1 yıl', style: s.kucuk),
          ]),
        );
      },
    );
  }
}

/// Ölçüm yorumu penceresini modüllerden açmak için kısa yol
void modulYorumAc(BuildContext context, OlcumYorum y) => showOlcumSheet(context, y);
