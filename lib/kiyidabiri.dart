import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'app_state.dart';
import 'bait_card.dart' show SearchResultsScreen;
import 'catches.dart';
import 'config.dart';
import 'freshwater.dart';
import 'harita_secici.dart';
import 'kiyidabiri_beyin.dart';
import 'main.dart' show Shell, shellTab;
import 'mera.dart';
import 'mera_oner.dart';
import 'meralarim.dart';
import 'models.dart';
import 'notices.dart';
import 'locate.dart';
import 'screens/knots_screen.dart';
import 'sea.dart';
import 'sea_card.dart';
import 'theme.dart';
import 'updates.dart';

/// 1.14.0 — Kıyıdabiri: ekranın altında duran mini robot. Dokununca sohbet açılır; açılışta (ayardan kapatılabilir)
/// Türkçe sesle karşılar. Sohbetler hizmeti iyileştirmek için sunucuya kaydedilir (yönetici paneli › Kıyıdabiri).

// =================================================================== ayarlar
class KiyidabiriAyar {
  static const _ses = 'kb_ses_v1', _gorunur = 'kb_gorunur_v1', _konum = 'kb_konum_v1', _cihaz = 'kb_cihaz_v1',
      _gizlilik = 'kb_gizlilik_v1';
  static final sesli = ValueNotifier<bool>(true);
  static final gorunur = ValueNotifier<bool>(true);
  /// Robotun ekrandaki yeri (0–1 oranı; varsayılan sol alt, alt menünün hemen üstü)
  static Offset konum = const Offset(0, 1);
  static String cihaz = '';
  static bool gizlilikGoruldu = false;

  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      sesli.value = p.getBool(_ses) ?? true;
      gorunur.value = p.getBool(_gorunur) ?? true;
      final k = p.getStringList(_konum);
      if (k != null && k.length == 2) konum = Offset(double.tryParse(k[0]) ?? 0, double.tryParse(k[1]) ?? 1);
      cihaz = p.getString(_cihaz) ?? '';
      if (cihaz.isEmpty) {
        cihaz = _rastgele(20);
        await p.setString(_cihaz, cihaz);
      }
      gizlilikGoruldu = p.getBool(_gizlilik) ?? false;
    } catch (_) {
      if (cihaz.isEmpty) cihaz = _rastgele(20);
    }
  }

  static Future<void> sesAyarla(bool v) async {
    sesli.value = v;
    if (!v) unawaited(KiyidabiriSes.dur());
    try {
      (await SharedPreferences.getInstance()).setBool(_ses, v);
    } catch (_) {}
  }

  static Future<void> gorunurAyarla(bool v) async {
    gorunur.value = v;
    try {
      (await SharedPreferences.getInstance()).setBool(_gorunur, v);
    } catch (_) {}
  }

  static Future<void> konumKaydet(Offset o) async {
    konum = o;
    try {
      (await SharedPreferences.getInstance()).setStringList(_konum, [o.dx.toStringAsFixed(3), o.dy.toStringAsFixed(3)]);
    } catch (_) {}
  }

  static Future<void> gizlilikOnay() async {
    gizlilikGoruldu = true;
    try {
      (await SharedPreferences.getInstance()).setBool(_gizlilik, true);
    } catch (_) {}
  }
}

String _rastgele(int n) {
  const h = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = math.Random.secure();
  return List.generate(n, (_) => h[r.nextInt(h.length)]).join();
}

// =================================================================== ses (TTS)
class KiyidabiriSes {
  static FlutterTts? _tts;
  static bool _karsiladi = false;
  static const karsilamaSozu = 'Merhaba ben Kıyıdabiri, sana yardımcı olmak için buradayım.';

  static Future<FlutterTts> _al() async {
    final t = _tts ??= FlutterTts();
    try {
      await t.setLanguage('tr-TR');
      await t.setSpeechRate(Platform.isIOS ? 0.48 : 0.5);
      await t.setPitch(1.15); // biraz daha "robot", sevimli
      await t.setVolume(1.0);
      if (Platform.isIOS) {
        // Sessiz moddaysa iPhone konuşmaz (kullanıcının tercihine saygı)
        await t.setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
      }
    } catch (_) {}
    return t;
  }

  static Future<void> konus(String metin) async {
    if (!KiyidabiriAyar.sesli.value) return;
    try {
      final t = await _al();
      await t.stop();
      await t.speak(metin.replaceAll(RegExp(r'[📍🎯🐟⚠️🔔🎣👋📌•]'), ''));
    } catch (_) {}
  }

  static Future<void> dur() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Uygulama açılışında bir kez
  static Future<void> karsila() async {
    if (_karsiladi || !KiyidabiriAyar.sesli.value || !KiyidabiriAyar.gorunur.value) return;
    _karsiladi = true;
    await konus(karsilamaSozu);
  }
}

// =================================================================== sunucuya kayıt
class KbKayit {
  static final List<Map<String, String>> _bekleyen = [];
  static String oturum = _rastgele(16);
  static bool _gonderiliyor = false;
  static String mera = '';

  static void ekle(String kim, String metin, {String niyet = ''}) {
    _bekleyen.add({'kim': kim, 'metin': metin, 'niyet': niyet, 'zaman': DateTime.now().toIso8601String()});
    if (_bekleyen.length > 120) _bekleyen.removeRange(0, _bekleyen.length - 120);
  }

  static Future<void> gonder() async {
    if (_gonderiliyor || _bekleyen.isEmpty) return;
    _gonderiliyor = true;
    final paket = List<Map<String, String>>.from(_bekleyen.take(40));
    try {
      final t = await CatchService.token();
      final r = await http
          .post(Uri.parse('${AppConfig.siteUrl}mobil-kiyidabiri.php?a=sohbet'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json', if (t != null) 'X-Av-Anahtar': t},
              body: jsonEncode({
                'cihaz': KiyidabiriAyar.cihaz,
                'oturum': oturum,
                'mera': mera,
                'platform': Platform.isIOS ? 'ios' : 'android',
                'surum': AppUpdate.name,
                'mesajlar': paket,
              }))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) _bekleyen.removeRange(0, paket.length);
    } catch (_) {
      // Ağ yoksa sonra yeniden denenir
    } finally {
      _gonderiliyor = false;
    }
  }
}

// =================================================================== kampanya hatırlatıcı
/// Kullanıcının "bu üründe kampanya olunca haber ver" istekleri. Uygulama açıkken ve arka planda
/// (bildirim denetimiyle birlikte) mağaza aranır; indirime giren ürün için bir kez bildirim düşer.
class KampanyaHatirlatici {
  static const _liste = 'kb_kampanya_v1', _bildirilen = 'kb_kampanya_bildirilen_v1', _son = 'kb_kampanya_son_v1';

  static Future<List<String>> istekler() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_liste) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> ekle(String urun) async {
    final u = urun.trim();
    if (u.length < 2) return;
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(_liste) ?? <String>[];
      if (!l.map((e) => e.toLowerCase()).contains(u.toLowerCase())) {
        l.insert(0, u);
        await p.setStringList(_liste, l.take(10).toList());
      }
    } catch (_) {}
    // Talep yönetici panelinde görünsün
    try {
      final t = await CatchService.token();
      await http.post(Uri.parse('${AppConfig.siteUrl}mobil-kiyidabiri.php?a=kampanya'),
          headers: {'Accept': 'application/json', if (t != null) 'X-Av-Anahtar': t},
          body: {'cihaz': KiyidabiriAyar.cihaz.isEmpty ? _rastgele(20) : KiyidabiriAyar.cihaz, 'urun': u}).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<void> sil(String urun) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_liste, (p.getStringList(_liste) ?? const []).where((e) => e != urun).toList());
    } catch (_) {}
  }

  /// En fazla 6 saatte bir: istenen ürünlerde indirim varsa bildirim
  static Future<void> kontrol({bool zorla = false}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(_liste) ?? const [];
      if (l.isEmpty) return;
      final son = p.getInt(_son) ?? 0;
      final simdi = DateTime.now().millisecondsSinceEpoch;
      if (!zorla && simdi - son < 6 * 3600 * 1000) return;
      await p.setInt(_son, simdi);
      final bildirilen = (p.getStringList(_bildirilen) ?? <String>[]).toSet();
      var yeni = 0;
      for (final urun in l) {
        final r = await Api.search(urun);
        for (final u in r.items.where((e) => e.special != null && e.special! < e.price).take(2)) {
          final id = 'kb_${u.id}_${u.special!.round()}';
          if (!bildirilen.add(id)) continue;
          if (yeni++ >= 3) break;
          await Notices.yerelGoster(Notice(
            id: id,
            type: 'urun',
            title: '🔔 Kampanya: ${u.name}',
            body: '"$urun" için beklediğin indirim geldi: ${_tl(u.price)} → ${_tl(u.special!)}',
            image: u.image ?? '',
            target: '${u.id}',
          ));
        }
      }
      await p.setStringList(_bildirilen, bildirilen.toList().reversed.take(300).toList());
    } catch (_) {}
  }

  static String _tl(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)} TL';
}

// =================================================================== gerçek veri
class _UygulamaVerisi implements KbVeri {
  @override
  Spot get secili => selectedSpot.value;
  @override
  bool get uye => appState.isMember;

  @override
  List<Spot> denizMeralari() => [
        ...Meralarim.liste.value.where((s) => s.side.public || uye),
        ...spots.where((s) => s.side.public || uye),
      ];

  @override
  List<MeraOnerisi> topluluk() => MeraOnerApi.onaylilar.value;

  @override
  Future<FwData?> tatliSu() async => uye ? FreshwaterService.load() : null;

  @override
  Future<SpotForecast> hafta(Spot s) => SeaService.fetchWeek(s);

  @override
  Future<List<SpotForecast>> simdi(List<Spot> l) => SeaService.fetchSpots(l);

  @override
  Future<MeraInfo?> kesit(Spot s) => MeraService.of(s).timeout(const Duration(seconds: 8), onTimeout: () => null);

  @override
  Future<List<ProductCard>> urunAra(String q) async => (await Api.search(q)).items;
}

// =================================================================== robot çizimi
class _RobotBoyaci extends CustomPainter {
  final double kirp; // göz kırpma 0–1
  final double salla; // anten salınımı -1..1
  _RobotBoyaci(this.kirp, this.salla);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()..isAntiAlias = true;
    // gövde gölgesi
    p.color = const Color(0x33000000);
    c.drawOval(Rect.fromCenter(center: Offset(w * .5, h * .95), width: w * .62, height: h * .08), p);
    // anten
    final tepe = Offset(w * .5 + salla * w * .06, h * .06);
    p
      ..color = Tide.zeytinKoyu
      ..strokeWidth = w * .035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(w * .5, h * .2), tepe, p);
    p.style = PaintingStyle.fill;
    p.color = Tide.turuncu;
    c.drawCircle(tepe, w * .065, p);
    // kafa (kask)
    final kafa = RRect.fromRectAndRadius(Rect.fromLTWH(w * .1, h * .18, w * .8, h * .56), Radius.circular(w * .26));
    p.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFE5EEF0)])
        .createShader(kafa.outerRect);
    c.drawRRect(kafa, p);
    p.shader = null;
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .03
      ..color = Tide.derin;
    c.drawRRect(kafa, p);
    p.style = PaintingStyle.fill;
    // yüz camı
    final cam = RRect.fromRectAndRadius(Rect.fromLTWH(w * .2, h * .3, w * .6, h * .32), Radius.circular(w * .16));
    p.color = Tide.derin;
    c.drawRRect(cam, p);
    // gözler
    p.color = const Color(0xFF7FE7F2);
    final gy = h * .45;
    final gh = math.max(h * .02, h * .12 * (1 - kirp));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .37, gy), width: w * .1, height: gh), Radius.circular(w * .05)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .63, gy), width: w * .1, height: gh), Radius.circular(w * .05)), p);
    // gülümseme
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .03
      ..color = const Color(0xFF7FE7F2);
    c.drawArc(Rect.fromCenter(center: Offset(w * .5, h * .52), width: w * .16, height: h * .08), 0.2, math.pi - 0.4, false, p);
    p.style = PaintingStyle.fill;
    // yanak ışıkları
    p.color = Tide.turuncu.withValues(alpha: .85);
    c.drawCircle(Offset(w * .1, h * .46), w * .05, p);
    c.drawCircle(Offset(w * .9, h * .46), w * .05, p);
    // küçük gövde + olta kancası rozeti
    final govde = RRect.fromRectAndRadius(Rect.fromLTWH(w * .3, h * .72, w * .4, h * .2), Radius.circular(w * .08));
    p.color = Tide.turuncu;
    c.drawRRect(govde, p);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .025
      ..color = Colors.white;
    final kanca = Path()
      ..moveTo(w * .53, h * .75)
      ..lineTo(w * .53, h * .84)
      ..arcToPoint(Offset(w * .45, h * .84), radius: Radius.circular(w * .04))
      ..lineTo(w * .45, h * .81);
    c.drawPath(kanca, p);
  }

  @override
  bool shouldRepaint(_RobotBoyaci o) => o.kirp != kirp || o.salla != salla;
}

/// Hareketli robot simgesi (sohbet başlığında ve düğmede)
class KiyidabiriRobot extends StatefulWidget {
  final double boy;
  const KiyidabiriRobot({super.key, this.boy = 54});

  @override
  State<KiyidabiriRobot> createState() => _KiyidabiriRobotState();
}

class _KiyidabiriRobotState extends State<KiyidabiriRobot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final t = _a.value;
          // 3,6 sn'de bir kısa göz kırpma, hafif yukarı-aşağı süzülme
          final kirp = t > .92 && t < .97 ? math.sin((t - .92) / .05 * math.pi) : 0.0;
          final dy = math.sin(t * 2 * math.pi) * widget.boy * .035;
          return Transform.translate(
            offset: Offset(0, dy),
            child: CustomPaint(
                size: Size.square(widget.boy), painter: _RobotBoyaci(kirp, math.sin(t * 4 * math.pi))),
          );
        },
      );
}

// =================================================================== ekrandaki düğme
/// Shell gövdesinin üstüne konur; alt menünün hemen üstünde, sürüklenebilir (bırakınca kenara yapışır)
class KiyidabiriKatmani extends StatefulWidget {
  final Widget child;
  const KiyidabiriKatmani({super.key, required this.child});

  /// Sohbeti başka yerden açmak için
  static final acSinyali = ValueNotifier<int>(0);

  @override
  State<KiyidabiriKatmani> createState() => _KiyidabiriKatmaniState();
}

class _KiyidabiriKatmaniState extends State<KiyidabiriKatmani> {
  static const _boy = 58.0, _kenar = 10.0;
  Offset? _surukle;
  bool _balon = false;
  Timer? _balonZaman;

  @override
  void initState() {
    super.initState();
    KiyidabiriKatmani.acSinyali.addListener(_ac);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted || !KiyidabiriAyar.gorunur.value) return;
      setState(() => _balon = true);
      _balonZaman = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _balon = false);
      });
      unawaited(KiyidabiriSes.karsila());
      unawaited(KampanyaHatirlatici.kontrol());
    });
  }

  @override
  void dispose() {
    KiyidabiriKatmani.acSinyali.removeListener(_ac);
    _balonZaman?.cancel();
    super.dispose();
  }

  void _ac() {
    setState(() => _balon = false);
    kiyidabiriAc(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KiyidabiriAyar.gorunur,
      builder: (context, gorunur, child) => LayoutBuilder(builder: (context, c) {
        final klavye = MediaQuery.of(context).viewInsets.bottom > 0;
        if (!gorunur || klavye) return child!;
        final maxX = c.maxWidth - _boy - _kenar * 2;
        final ust = MediaQuery.of(context).padding.top + 80;
        final maxY = c.maxHeight - _boy - _kenar - ust;
        final o = _surukle ?? KiyidabiriAyar.konum;
        final x = _kenar + (o.dx.clamp(0.0, 1.0)) * maxX;
        final y = ust + (o.dy.clamp(0.0, 1.0)) * maxY;
        final solda = x < c.maxWidth / 2;
        return Stack(children: [
          child!,
          if (_balon)
            Positioned(
              left: solda ? x + _boy + 4 : null,
              right: solda ? null : c.maxWidth - x + 4,
              top: y - 6,
              child: _Balon(
                  metin: 'Merhaba, ben Kıyıdabiri!\nSana yardımcı olmak için buradayım 👋',
                  onTap: _ac),
            ),
          Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: _ac,
              onPanUpdate: (d) => setState(() {
                final s = _surukle ?? KiyidabiriAyar.konum;
                _surukle = Offset((s.dx + d.delta.dx / maxX).clamp(0.0, 1.0), (s.dy + d.delta.dy / maxY).clamp(0.0, 1.0));
              }),
              onPanEnd: (_) {
                final s = _surukle ?? KiyidabiriAyar.konum;
                final yeni = Offset(s.dx < .5 ? 0 : 1, s.dy); // en yakın kenara yapış
                setState(() => _surukle = null);
                KiyidabiriAyar.konumKaydet(yeni);
              },
              child: Semantics(
                button: true,
                label: 'Kıyıdabiri yardımcı robotu',
                child: Container(
                  width: _boy,
                  height: _boy,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Tide.turuncu, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const KiyidabiriRobot(boy: 46),
                ),
              ),
            ),
          ),
        ]);
      }),
      child: widget.child,
    );
  }
}

class _Balon extends StatelessWidget {
  final String metin;
  final VoidCallback onTap;
  const _Balon({required this.metin, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Material(
          elevation: 4,
          color: Tide.derin,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(metin, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

// =================================================================== sohbet
class _Mesaj {
  final bool robot;
  final String metin;
  final List<KbSecenek> secenekler;
  final Spot? spot;
  const _Mesaj(this.robot, this.metin, {this.secenekler = const [], this.spot});
}

/// Sohbet geçmişi uygulama açık kaldıkça korunur
final List<_Mesaj> _gecmis = [];
KiyidabiriBeyin? _beyin;

Future<void> kiyidabiriAc(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF7F5EE),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const FractionallySizedBox(heightFactor: .88, child: KiyidabiriSohbet()),
  );
  unawaited(KbKayit.gonder());
}

class KiyidabiriSohbet extends StatefulWidget {
  /// Testte sahte veriyle
  final KbVeri? veri;
  const KiyidabiriSohbet({super.key, this.veri});

  @override
  State<KiyidabiriSohbet> createState() => _KiyidabiriSohbetState();
}

class _KiyidabiriSohbetState extends State<KiyidabiriSohbet> {
  final _yazi = TextEditingController();
  final _kaydir = ScrollController();
  bool _dusunuyor = false;
  late final KiyidabiriBeyin _b;

  @override
  void initState() {
    super.initState();
    if (widget.veri != null) {
      _b = KiyidabiriBeyin(widget.veri!);
      _gecmis.clear();
    } else {
      _b = _beyin ??= KiyidabiriBeyin(_UygulamaVerisi());
    }
    unawaited(_b.hazirla());
    if (_gecmis.isEmpty) {
      _gecmis.add(_Mesaj(true, KiyidabiriBeyin.karsilama, secenekler: _b.acilisSecenekleri));
      KbKayit.ekle('robot', KiyidabiriBeyin.karsilama, niyet: 'karsilama');
    }
    _asagi();
  }

  @override
  void dispose() {
    _yazi.dispose();
    _kaydir.dispose();
    KiyidabiriSes.dur();
    super.dispose();
  }

  void _asagi() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_kaydir.hasClients) {
          _kaydir.animateTo(_kaydir.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _gonder(String metin) async {
    final m = metin.trim();
    if (m.isEmpty || _dusunuyor) return;
    _yazi.clear();
    setState(() {
      _gecmis.add(_Mesaj(false, m));
      _dusunuyor = true;
    });
    _asagi();
    KbYanit y;
    try {
      y = await _b.yanitla(m);
    } catch (_) {
      y = const KbYanit('Bir sorun oldu, tekrar dener misin?', niyet: 'hata');
    }
    KbKayit.ekle('kullanici', m, niyet: y.niyet);
    KbKayit.ekle('robot', y.metin, niyet: y.niyet);
    if (y.spot != null) KbKayit.mera = y.spot!.name;
    if (y.kampanya != null) unawaited(KampanyaHatirlatici.ekle(y.kampanya!));
    if (!mounted) return;
    setState(() {
      _dusunuyor = false;
      _gecmis.add(_Mesaj(true, y.metin, secenekler: y.secenekler, spot: y.spot));
    });
    _asagi();
    unawaited(KiyidabiriSes.konus(y.metin.split('\n').first));
    unawaited(KbKayit.gonder());
  }

  Future<void> _secenek(KbSecenek s, Spot? spot) async {
    switch (s.eylem) {
      case null:
        await _gonder(s.gonder ?? s.etiket);
      case KbEylem.whatsapp:
        final metin = Uri.encodeComponent('Merhaba, KıyıdanAv uygulamasındaki Kıyıdabiri\'nden yazıyorum. '
            '${_gecmis.where((e) => !e.robot).map((e) => e.metin).lastOrNull ?? ''}');
        KbKayit.ekle('kullanici', '[WhatsApp temsilcisine yönlendi]', niyet: 'whatsapp');
        unawaited(KbKayit.gonder());
        await launchUrl(Uri.parse('https://wa.me/${AppConfig.whatsapp}?text=$metin'), mode: LaunchMode.externalApplication);
      case KbEylem.haritadanSec:
        final secilen = await haritadanSec(context, baslik: 'Hangi meradasın?');
        if (secilen != null && mounted) await _gonder(secilen.name);
      case KbEylem.meraBilgisiAc:
        final sp = spot ?? _b.sonMera;
        if (sp == null) return;
        if (!sp.side.public && !appState.isMember) {
          showMemberPrompt(context, '${sp.side.label} meraları');
          return;
        }
        if (sp.nokta) await Meralarim.ekle(sp);
        await Locate.manualPick(sp);
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
        shellTab.value = Shell.tabReport;
      case KbEylem.meraOner:
        await meraOner(context, MeraTuru.tuzlu);
      case KbEylem.toplulukMeralari:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeraOnerileriEkrani()));
      case KbEylem.dugumler:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KnotsScreen()));
      case KbEylem.bildirimIzni:
        final ok = await Notices.ensurePermission(context, explain: true);
        if (mounted) {
          setState(() => _gecmis.add(_Mesaj(true,
              ok ? 'Bildirimler açık. Kampanya gelince haber vereceğim 🔔' : 'Bildirim izni verilmedi; telefon ayarlarından açabilirsin.')));
          _asagi();
        }
      case KbEylem.urunAra:
        final q = s.gonder ?? s.etiket;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchResultsScreen(query: q, title: q)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Başlık
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
        decoration: const BoxDecoration(
          color: Tide.derin,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const KiyidabiriRobot(boy: 40),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kıyıdabiri', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Mera asistanın · KıyıdanAv verisiyle yanıtlar',
                  style: TextStyle(color: Color(0xFFBFD6D1), fontSize: 12)),
            ]),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: KiyidabiriAyar.sesli,
            builder: (_, sesli, __) => IconButton(
              tooltip: sesli ? 'Sesi kapat' : 'Sesi aç',
              onPressed: () => KiyidabiriAyar.sesAyarla(!sesli),
              icon: Icon(sesli ? Icons.volume_up : Icons.volume_off, color: Colors.white),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) async {
              if (v == 'gizle') {
                await KiyidabiriAyar.gorunurAyarla(false);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Kıyıdabiri gizlendi. Hesabım › Kıyıdabiri ayarlarından yeniden açabilirsin.')));
                }
              } else if (v == 'yeni') {
                setState(() {
                  _gecmis
                    ..clear()
                    ..add(_Mesaj(true, KiyidabiriBeyin.karsilama, secenekler: _b.acilisSecenekleri));
                  _b.adim = KbAdim.mera;
                  KbKayit.oturum = _rastgele(16);
                });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'yeni', child: Text('Yeni sohbet')),
              PopupMenuItem(value: 'gizle', child: Text('Robotu ekrandan gizle')),
            ],
          ),
        ]),
      ),
      if (!KiyidabiriAyar.gizlilikGoruldu)
        Container(
          width: double.infinity,
          color: const Color(0xFFFFF4EC),
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(children: [
            const Icon(Icons.privacy_tip_outlined, size: 18, color: Tide.turuncu),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                  'Sohbetler hizmeti iyileştirmek için KıyıdanAv sunucusuna kaydedilir. Telefon, adres gibi kişisel bilgi yazma.',
                  style: TextStyle(fontSize: 12, height: 1.3)),
            ),
            TextButton(
                onPressed: () => setState(() => KiyidabiriAyar.gizlilikOnay()), child: const Text('Tamam')),
          ]),
        ),
      Expanded(
        child: ListView.builder(
          controller: _kaydir,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: _gecmis.length + (_dusunuyor ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _gecmis.length) return const _Yaziyor();
            final m = _gecmis[i];
            final son = i == _gecmis.length - 1;
            return Column(crossAxisAlignment: m.robot ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
              Align(
                alignment: m.robot ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: m.robot ? Colors.white : Tide.somon,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(m.robot ? 4 : 16),
                      bottomRight: Radius.circular(m.robot ? 16 : 4),
                    ),
                    border: m.robot ? Border.all(color: const Color(0xFFE6E2D6)) : null,
                  ),
                  child: SelectableText(m.metin, style: const TextStyle(fontSize: 14.5, height: 1.38)),
                ),
              ),
              if (m.robot && son && m.secenekler.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in m.secenekler)
                      ActionChip(
                        label: Text(s.etiket),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Tide.turuncu),
                        labelStyle: const TextStyle(color: Tide.zeytinKoyu, fontWeight: FontWeight.w700),
                        avatar: s.eylem == KbEylem.whatsapp ? const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)) : null,
                        onPressed: () => _secenek(s, m.spot),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      ),
      // Yazma alanı
      SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 6, 10, 8 + MediaQuery.of(context).viewInsets.bottom),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _yazi,
                textInputAction: TextInputAction.send,
                onSubmitted: _gonder,
                maxLength: 300,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Kıyıdabiri\'ye sor…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Tide.turuncu),
              onPressed: () => _gonder(_yazi.text),
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Yaziyor extends StatelessWidget {
  const _Yaziyor();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Tide.turuncu)),
            SizedBox(width: 8),
            Text('Kıyıdabiri mera verilerine bakıyor…', style: TextStyle(color: Tide.misina, fontSize: 13)),
          ]),
        ),
      );
}

/// Hesabım ekranı için ayar kartı
class KiyidabiriAyarKarti extends StatelessWidget {
  const KiyidabiriAyarKarti({super.key});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          ListTile(
            leading: const SizedBox(width: 36, height: 36, child: KiyidabiriRobot(boy: 36)),
            title: const Text('Kıyıdabiri', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Mera asistanı robot'),
            trailing: TextButton(onPressed: () => kiyidabiriAc(context), child: const Text('Sohbet aç')),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: KiyidabiriAyar.gorunur,
            builder: (_, v, __) => SwitchListTile(
              title: const Text('Robot ekranda görünsün'),
              value: v,
              onChanged: KiyidabiriAyar.gorunurAyarla,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: KiyidabiriAyar.sesli,
            builder: (_, v, __) => SwitchListTile(
              title: const Text('Açılışta sesli karşılama'),
              subtitle: const Text('"Merhaba ben Kıyıdabiri…" (telefonun Türkçe sesiyle)'),
              value: v,
              onChanged: KiyidabiriAyar.sesAyarla,
            ),
          ),
        ]),
      );
}
