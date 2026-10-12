import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'main.dart';
import 'notices.dart';
import 'theme.dart';

/// Köşesinde kapatma (X) düğmesi olan pencere. Uygulamadaki tüm uyarı pencereleri bunu kullanır.
class AppDialog extends StatelessWidget {
  final Widget? icon;
  final String? title;
  final Widget? content;
  final List<Widget> actions;

  /// X'e basılınca dönecek değer (ör. "Şimdi değil" ile aynı: false)
  final Object? closeResult;

  const AppDialog({super.key, this.icon, this.title, this.content, this.actions = const [], this.closeResult});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (icon != null) Center(child: icon),
            if (icon != null) const SizedBox(height: 10),
            if (title != null)
              Padding(
                padding: EdgeInsets.only(right: icon == null ? 28 : 0),
                child: Text(title!,
                    textAlign: icon == null ? TextAlign.start : TextAlign.center,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Tide.kaya)),
              ),
            if (content != null) ...[
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14.5, height: 1.45), child: content!),
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: actions),
            ],
          ]),
        ),
        Positioned(top: 4, right: 4, child: CloseX(onTap: () => Navigator.of(context).pop(closeResult))),
      ]),
    );
  }
}

/// Küçük yuvarlak kapatma düğmesi
class CloseX extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final Color background;
  const CloseX({super.key, required this.onTap, this.color = Tide.kaya, this.background = const Color(0x14000000)});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Kapat',
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.close, size: 18, color: color)),
        ),
      ),
    );
  }
}

// =====================================================================
// Kampanya bandı: yeni kampanya pencere olarak açılmaz, uygulamanın üstünde kayan yazı olarak durur
// =====================================================================

class CampaignTicker {
  static const _key = 'kampanya_bant_kapali';
  static final dismissed = ValueNotifier<Set<String>>(<String>{});

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      dismissed.value = (p.getStringList(_key) ?? const []).toSet();
    } catch (_) {}
  }

  static Future<void> dismiss(Iterable<String> ids) async {
    final s = {...dismissed.value, ...ids};
    dismissed.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, s.toList().reversed.take(200).toList());
    } catch (_) {}
  }

  /// Bantta gösterilecekler: son 7 günün, kapatılmamış kampanya/ürün/kategori bildirimleri
  static List<Notice> active(List<Notice> all, Set<String> closed) {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    return all.where((n) {
      if (n.type == 'rapor' || closed.contains(n.id)) return false;
      final t = DateTime.tryParse(n.date);
      return t == null || t.isAfter(limit);
    }).take(3).toList();
  }
}

/// Sayfaların üstüne bandı yerleştirir (bant yokken hiçbir şey değişmez)
class TickerHost extends StatelessWidget {
  final Widget child;
  const TickerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Notice>>(
      valueListenable: Notices.items,
      builder: (context, all, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: CampaignTicker.dismissed,
        builder: (context, closed, _) {
          final list = CampaignTicker.active(all, closed);
          if (list.isEmpty) return child;
          return Column(children: [
            Container(
              color: Tide.turuncu,
              child: SafeArea(bottom: false, child: _TickerBar(list)),
            ),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
          ]);
        },
      ),
    );
  }
}

class _TickerBar extends StatelessWidget {
  final List<Notice> list;
  const _TickerBar(this.list);

  @override
  Widget build(BuildContext context) {
    final text = list
        .map((n) => n.body.isEmpty ? n.title : '${n.title} — ${n.body.replaceAll('\n', ' ')}')
        .join('      •      ');
    return SizedBox(
      height: 40,
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Icon(Icons.campaign, color: Colors.white, size: 22),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              // Açılan kampanya bantta tekrar dönmesin
              CampaignTicker.dismiss(list.map((n) => n.id));
              if (list.length == 1) {
                Notices.open(list.first);
              } else {
                navKey.currentState?.push(MaterialPageRoute(builder: (_) => const NoticesScreen()));
              }
            },
            child: Marquee(
              text: text,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: CloseX(
            color: Colors.white,
            background: const Color(0x33000000),
            onTap: () => CampaignTicker.dismiss(list.map((n) => n.id)),
          ),
        ),
      ]),
    );
  }
}

/// Sağdan sola sürekli kayan tek satır yazı
class Marquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed; // piksel / saniye
  const Marquee({super.key, required this.text, required this.style, this.speed = 45});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final w = box.maxWidth;
      final textW = tp.width;
      final travel = w + textW;
      final ms = (travel / widget.speed * 1000).round().clamp(2000, 120000);
      if (_c.duration?.inMilliseconds != ms) {
        _c.duration = Duration(milliseconds: ms);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _c.repeat();
        });
      }
      return ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: w - travel * _c.value,
              top: 0,
              bottom: 0,
              child: Center(child: Text(widget.text, maxLines: 1, softWrap: false, style: widget.style)),
            ),
          ]),
        ),
      );
    });
  }
}

// =====================================================================
// İlk giriş penceresi: Mera Bilgisi tanıtımı (bir kez, 5 saniyede kendiliğinden kapanır)
// =====================================================================

class WelcomePopup {
  static const _key = 'hosgeldin_mera_v1';
  static bool _showing = false;

  /// Uygulama açılışında ve üye girişi yapıldığında çağrılır
  static Future<void> maybeShow() async {
    if (_showing || !memberNotifier.value) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_key) ?? false) return;
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null || !ctx.mounted) return;
    _showing = true;
    await p.setBool(_key, true);
    try {
      await showDialog(context: ctx, builder: (_) => const _WelcomeDialog());
    } finally {
      _showing = false;
    }
  }
}

class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> with SingleTickerProviderStateMixin {
  static const _life = Duration(seconds: 5);
  late final AnimationController _c = AnimationController(vsync: this, duration: _life)..forward();
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    });
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 44, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Tide.derin, Tide.derinAcik]),
            ),
            child: const Row(children: [
              Icon(Icons.set_meal, color: Color(0xFFFFD54F), size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text('Mera Bilgisi ile avın şansını artır',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Line(Icons.place_outlined, 'Meranı seç; rüzgâr, dalga, su sıcaklığı, ay evresi ve uydu verisinden '
                  'hesaplanan av verimliliğini gör.'),
              _Line(Icons.schedule, 'En verimli saatleri ve 7 günlük hava tahminini tek ekranda takip et.'),
              _Line(Icons.phishing, 'Avını bildir, diğer balıkçıların son 48 saatte nerede ne tuttuğunu öğren.'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                _close();
                shellTab.value = Shell.tabReport;
              },
              icon: const Icon(Icons.set_meal),
              label: const Text('Mera Bilgisi\'ni aç'),
            ),
          ),
          // Kalan süre (5 sn)
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => LinearProgressIndicator(
              value: 1 - _c.value,
              minHeight: 4,
              color: Tide.turuncu,
              backgroundColor: const Color(0x14000000),
            ),
          ),
        ]),
        Positioned(
          top: 8,
          right: 8,
          child: CloseX(onTap: _close, color: Colors.white, background: const Color(0x33FFFFFF)),
        ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Tide.turuncu),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
      ]),
    );
  }
}
