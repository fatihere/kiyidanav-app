import 'dart:ui' show ImageFilter;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ambience.dart';
import '../badi.dart';
import '../bolge_baliklari.dart';
import '../fishkrok.dart';
import '../kiyilama.dart';
import '../kurallar.dart';
import '../api.dart';
import '../araclar.dart';
import '../bait_card.dart';
import '../catches.dart';
import '../cevrimdisi.dart';
import 'catch_screens.dart';
import 'freshwater_screen.dart';
import 'knots_screen.dart';
import '../locate.dart';
import '../main.dart';
import '../mera_widget.dart';
import '../mera.dart';
import '../modul_kartlari.dart';
import '../moduller.dart';
import '../premium.dart';
import '../olcum_sheet.dart';
import '../olcum_yorum.dart';
import '../models.dart';
import '../sea.dart';
import '../sea_card.dart';
import '../share.dart';
import '../share_card.dart';
import '../app_state.dart';
import '../solunar.dart';
import '../theme.dart';
import '../weather_icon.dart';

const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

String _tarih(DateTime d) => '${d.day} ${ayAdlari[d.month]} ${d.year}';
String _saat(DateTime? d) =>
    d == null ? '—' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with WidgetsBindingObserver {
  final _shotKey = GlobalKey();
  Future<_ReportData>? _future;
  String? _forSpot;
  bool _sharing = false;
  SeaMood? _mood;
  _ReportData? _widgetData; // ana ekran kartına en son yazılan rapor

  @override
  void initState() {
    super.initState();
    // Modül kartlarındaki "Önerilen ürünleri gör" düğmesi uygulamanın ürün aramasını açar
    modulUrunAc = (ctx, ara, baslik) => Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: ara, title: baslik, bait: true)));
    WidgetsBinding.instance.addObserver(this);
    shellTab.addListener(_onTab);
    Ambience.on.addListener(_syncSound);
    Premium.aktif.addListener(_premiumDegisti);
    Ambience.load(defaultOn: Api.config.ui.meraSesAcik);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shellTab.removeListener(_onTab);
    Ambience.on.removeListener(_syncSound);
    Premium.aktif.removeListener(_premiumDegisti);
    Ambience.stop();
    super.dispose();
  }

  void _premiumDegisti() {
    if (mounted) setState(() {});
  }

  /// Uygulamadan çıkınca (ana ekran, başka uygulama, ekran kilidi) ortam sesi durur; dönünce kaldığı yerden çalar
  bool _onPlanda = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _onPlanda = state == AppLifecycleState.resumed;
    _syncSound();
  }

  bool get _visible => shellTab.value == Shell.tabReport;

  bool _konumSoruldu = false;

  void _onTab() {
    _syncSound();
    // 1.12.0: Mera Bilgisi ilk açıldığında konumdan otomatik mera
    if (_visible && !_konumSoruldu && Api.config.features.location && memberNotifier.value) {
      _konumSoruldu = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Locate.ilkAcilis(context);
      });
    }
  }

  /// Ses yalnızca bu sekme açıkken, kullanıcı açtıysa ve üye içeriği görünürken çalar
  void _syncSound() {
    final m = _mood;
    if (_onPlanda && _visible && m != null && Ambience.on.value && memberNotifier.value && Api.config.features.ambientSound) {
      Ambience.play(m, volume: Api.config.ui.meraSesSeviye);
    } else {
      Ambience.stop();
    }
  }

  void _ensure(Spot s) {
    if (_forSpot != s.name) {
      _forSpot = s.name;
      _future = _load(s);
    }
  }

  /// Deniz/hava tahmini + bu meranın son avları + uydu verisi (ek veriler gecikirse rapor beklemez)
  Future<_ReportData> _load(Spot s) async {
    final fx = Api.config.features;
    final sat = fx.satellite
        ? SatService.of(s.lat, s.lon).timeout(const Duration(seconds: 10), onTimeout: () => null)
        : Future<SatInfo?>.value(null);
    final catches = fx.catchList
        ? CatchService.forSpot(s.key).timeout(const Duration(seconds: 8), onTimeout: () => const <CatchReport>[])
        : Future<List<CatchReport>>.value(const []);
    final info = MeraService.of(s).timeout(const Duration(seconds: 8), onTimeout: () => null);
    final f = await SeaService.fetchWeek(s);
    return _ReportData(f, await catches, await sat, await info);
  }

  Future<void> _share(SpotForecast f, int score, SeaMood mood, SatInfo? sat) async {
    setState(() => _sharing = true);
    final text = '${f.spot.name} günlük mera balık bilgisi: av verimliliği %$score, '
        '${Moon.phaseName(DateTime.now())}. KıyıdanAv uygulamasıyla hazırlandı 🎣 kiyidanav.com';
    try {
      final bytes = await ShareCard.render(_cardData(f, score, mood, sat)).timeout(const Duration(seconds: 12));
      if (bytes == null) throw StateError('görsel boş');
      Sharer.imageBytes(bytes, text: text);
    } catch (_) {
      // Görsel hazırlanamazsa (ya da çok uzun sürerse) en azından yazılı rapor paylaşılsın
      Sharer.textOnly(text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rapor görseli hazırlanamadı, yazılı rapor paylaşılıyor.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Paylaşım kartı içeriği (ekrandaki raporla aynı veriler, sade düzen)
  ShareCardData _cardData(SpotForecast f, int score, SeaMood mood, SatInfo? sat) {
    final r = f.now;
    final now = DateTime.now();
    final trend = f.pressureTrend;
    final today = f.days.isNotEmpty ? f.days.first : null;
    final dynamicBg = Api.config.ui.meraDinamikZemin && Api.config.features.dynamicBackground;
    String win(DateTime? t) =>
        '${_saat(t?.subtract(const Duration(hours: 1)))} – ${_saat(t?.add(const Duration(hours: 1)))}';
    const kisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return ShareCardData(
      place: '${f.spot.name} · ${f.spot.side.label}',
      date: '${_tarih(now)} · ${_gunler[now.weekday - 1]}',
      score: score,
      scoreLabel: FishingScore.label(score),
      moonName: Moon.phaseName(now),
      moonPct: (Moon.illumination(now) * 100).round(),
      verdict: r.verdict,
      moon: MoonPainter(now),
      colors: dynamicBg ? mood.colors : fixedMoodColors,
      chips: [
        (Icons.air, 'Rüzgâr', '${r.windKmh?.round() ?? '-'} km/s ${r.windFrom}'),
        (Icons.waves, 'Dalga', r.strait ? '${f.spot.shelter} içi' : (r.waveM == null ? '—' : '${r.waveM!.toStringAsFixed(1)} m')),
        (Icons.thermostat, 'Su / Hava', '${r.seaC?.round() ?? '-'}° / ${r.airC?.round() ?? '-'}°'),
        (Icons.speed, 'Basınç',
            r.pressure == null ? '—' : '${r.pressure!.round()} hPa ${trend == null ? '' : (trend < -0.8 ? '↘' : trend > 0.8 ? '↗' : '→')}'),
        if (r.gustKmh != null) (Icons.storm, 'Hamle', '${r.gustKmh!.round()} km/s'),
        if (sat?.sst != null) (Icons.satellite_alt_outlined, 'Uydu su sıcaklığı', '${sat!.sst!.toStringAsFixed(1)}°'),
        if (r.rainDay != null) (Icons.water_drop_outlined, 'Yağış (gün)', '${r.rainDay!.toStringAsFixed(r.rainDay! < 10 ? 1 : 0)} mm'),
      ],
      morning: win(today?.sunrise),
      evening: win(today?.sunset),
      days: [
        for (final d in f.days.take(7))
          (
            kisa[d.date.weekday - 1],
            FishingScore.compute(d.date.add(const Duration(hours: 12)),
                windKmh: d.effectiveWind, waveM: d.waveMax, rainMm: d.rainSum),
            WeatherLook.of(d.weatherCode).icon,
            WeatherLook.of(d.weatherCode).color,
          ),
      ],
    );
  }


  /// "Raporu paylaş" + ortam sesi düğmeleri
  Widget _paylasSatiri(SpotForecast f, int score, SeaMood mood, SatInfo? sat) {
    return Padding(
  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
  child: Row(children: [
    Expanded(
      child: SizedBox(
    height: 50,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
          backgroundColor: Tide.turuncu,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: _sharing ? null : () => _share(f, score, mood, sat),
      icon: const Icon(Icons.ios_share),
      label: Text(_sharing ? 'Hazırlanıyor…' : 'Raporu paylaş',
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
      ),
    ),
    if (Api.config.features.ambientSound) ...[
    const SizedBox(width: 10),
    ValueListenableBuilder<bool>(
      valueListenable: Ambience.on,
      builder: (_, on, __) => SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Tide.zeytinKoyu,
            side: BorderSide(color: on ? Tide.turuncu : const Color(0xFFD9D5C7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: Ambience.toggle,
          icon: Icon(on ? Icons.volume_up : Icons.volume_off,
              color: on ? Tide.turuncu : Tide.misina),
          label: Text(on ? mood.label : 'Ses'),
        ),
      ),
    ),
    ],
  ]),
);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Spot>(
      valueListenable: selectedSpot,
      builder: (context, spot, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Günlük Mera Balık Bilgisi'),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Tide.zeytinKoyu),
                onPressed: () => Premium.panel('konum') == PanelDurum.kilitli ? premiumSayfasi(context) : showSpotPicker(context),
                icon: const Icon(Icons.place_outlined),
                label: const Text('Konum', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: MemberGate(
           child: Builder(builder: (context) {
            _ensure(spot);
            return FutureBuilder<_ReportData>(
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
              final data = snap.data!;
              final f = data.f;
              final now = DateTime.now();
              final today = f.days.isNotEmpty ? f.days.first : null;
              final score = FishingScore.compute(now,
                  windKmh: f.now.effectiveWind,
                  waveM: f.now.effectiveWave,
                  pressureTrend: f.pressureTrend,
                  rainMm: f.now.rainDay,
                  currentKmh: f.now.currentKmh,
                  recentCatches: data.catches.length,
                  sstChange5d: data.sat?.sstChange5d,
                  chlChangePct: data.sat?.chlChangePct);
              if (!identical(_widgetData, data)) {
                _widgetData = data;
                MeraWidget.fromReport(f, score); // Android ana ekran kartı
              }
              final mood = SeaMood.of(f.now, waveThreshold: Api.config.waveThreshold);
              if (_mood != mood) {
                _mood = mood;
                WidgetsBinding.instance.addPostFrameCallback((_) => _syncSound());
              }
              final kiyilama = bugunkuKiyilama(f, data.sat, now, data.info);
              final fx = Api.config.features;
              // Panel → Topluluk → Mera düzeni: bölümlerin sırası ve kapalı olanlar
              final bolumler = <String, List<Widget> Function()>{
                'konum': () => [
                      if (fx.location) const PremiumKilit(panel: 'konum', ad: 'Konum seçimi', yukseklik: 90, child: LocationBar()),
                    ],
                'rapor': () => [
                      ModulAlani(f: f, sat: data.sat, now: now, uye: memberNotifier.value, konum: ModulKonum.ust),
                      PremiumKilit(
                        panel: 'rapor',
                        ad: 'Günlük rapor',
                        yukseklik: 320,
                        child: RepaintBoundary(
                          key: _shotKey,
                          child: _ReportCard(
                              f: f, score: score, today: today, now: now, mood: mood, sat: data.sat, catches: data.catches, info: data.info),
                        ),
                      ),
                    ],
                'paylas': () => [_paylasSatiri(f, score, mood, data.sat)],
                'kurallar': () => [if (fx.kurallar) KuralKarti(f: f, bugunSkor: score)],
                'moduller': () => [ModulAlani(f: f, sat: data.sat, now: now, uye: memberNotifier.value)],
                'avlar': () => [
                      if (fx.catchList || fx.catchSubmit)
                        PremiumKilit(panel: 'avlar', ad: 'Son 48 saat avları', child: SpotCatchesCard(spot: f.spot)),
                    ],
                'fishkrok': () => [if (fx.fishkrok) FishkrokGirisKarti(onTap: () => shellTab.value = Shell.tabFishkrok)],
                'badi': () => [if (fx.badi) const BadiGirisKarti()],
                'baliklar': () => [BolgeBaliklariKarti(spot: f.spot, kiyilama: kiyilama)],
                'araclar': () => [PremiumKilit(panel: 'araclar', ad: 'Av araçları', yukseklik: 120, child: AraclarKarti(mera: f.spot.key))],
                'istat': () => [
                      if (Moduller.app('bildirim_mesafe', uye: memberNotifier.value) != null)
                        PremiumKilit(
                            panel: 'istat',
                            ad: 'Av istatistiği',
                            child: AvIstatKarti(m: Moduller.app('bildirim_mesafe', uye: memberNotifier.value)!, spot: f.spot)),
                    ],
                'kesit': () => [PremiumKilit(panel: 'kesit', ad: 'Kıyı kesiti', yukseklik: 110, child: _MeraTile(spot: f.spot))],
                'yem': () => [if (fx.baitCard) const PremiumKilit(panel: 'yem', ad: 'Hangi ay hangi balık', child: BaitCard())],
                'tatli': () => [
                      if (fx.freshwater)
                        const PremiumKilit(panel: 'tatli', ad: 'Tatlı su meraları', yukseklik: 100, child: FreshwaterEntry()),
                    ],
                'dugum': () => [
                      if (Api.config.knots) const PremiumKilit(panel: 'dugum', ad: 'Balıkçı düğümleri', yukseklik: 100, child: KnotsEntry()),
                    ],
              };
              final sira = [
                ...Api.config.meraSira.where(bolumler.containsKey),
                ...bolumler.keys.where((k) => !Api.config.meraSira.contains(k)),
              ].where((k) => !Api.config.meraKapali.contains(k));
              return ListView(
                padding: const EdgeInsets.only(bottom: 32, top: 4),
                children: [
                  const CevrimdisiSerit(),
                  for (final k in sira) ...bolumler[k]!(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      scoreSourcesText(Api.config.features),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF77766A)),
                    ),
                  ),
                ],
              );
            },
          );
          }),
          ),
        );
      },
    );
  }
}

/// Kıyı kesiti (derinlik ve dip yapısı) kartı
class _MeraTile extends StatelessWidget {
  final Spot spot;
  const _MeraTile({required this.spot});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MeraInfo?>(
      future: MeraService.of(spot),
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        // Panelde "Kesit 0–200 m + şev" modülü açıksa profil çizimli kart
        final kesit = Moduller.app('kesit_200', uye: memberNotifier.value);
        if (kesit != null && info.profile.isNotEmpty) return KesitKarti(m: kesit, spot: spot, info: info);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Material(
            color: Tide.derin,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showMeraSheet(context, spot, info),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.layers_outlined, color: Color(0xFFFFD54F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Kıyı derinliği ve dip yapısı',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(info.summary, style: const TextStyle(color: Color(0xFFBFD6D1), fontSize: 13)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ]),
              ),
            ),
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
  final SeaMood mood;
  final SatInfo? sat;
  final List<CatchReport> catches;
  final MeraInfo? info;
  const _ReportCard(
      {required this.f,
      required this.score,
      required this.today,
      required this.now,
      required this.mood,
      this.sat,
      this.catches = const [],
      this.info});

  @override
  Widget build(BuildContext context) {
    final r = f.now;
    final trend = f.pressureTrend;
    final fx = Api.config.features;
    final dynamicBg = Api.config.ui.meraDinamikZemin && fx.dynamicBackground;
    final colors = dynamicBg ? mood.colors : fixedMoodColors;
    final intensity = ((r.effectiveWind / 45) + (r.effectiveWave / 2) + ((r.rainNow ?? 0) / 3)).clamp(0.2, 1.0);
    // Kıyılama ve başlık cümlesi: puan, rüzgâr/dalga ve meranın yapısı aynı hesaptan (1.12.0)
    final kiyilama = bugunkuKiyilama(f, sat, now, info);
    final hukum = raporHukmu(puan: score, ruzgar: r.effectiveWind, dalga: r.effectiveWave, k: kiyilama, yagisli: r.rainy);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(children: [
        if (dynamicBg) Positioned.fill(child: MoodOverlay(mood: mood, intensity: intensity.toDouble())),
        Padding(
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
              Text('${f.spot.name} · ${f.spot.side.label}',
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
                  style: TextStyle(color: Color(0xFFCFE3E0), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(width: 34, height: 34, child: CustomPaint(painter: MoonPainter(now))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Moon.phaseName(now),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('%${(Moon.illumination(now) * 100).round()} aydınlık',
                        style: const TextStyle(color: Color(0xFFD6E9E6), fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              _FishRow(FishingScore.fishCount(score)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Text(hukum, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        // Kıyılama: büyük / küçük balık bugün kaç metrede (meranın şevi + rüzgârın kıyıya göre yönü)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KIYILAMA', style: TextStyle(color: Color(0xFFCFE3E0), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _kiyilamaKutu('Küçük balık', kiyilama.kucuk, const Color(0xFF7FD1C7))),
              const SizedBox(width: 8),
              Expanded(child: _kiyilamaKutu('Büyük balık', kiyilama.buyuk, Tide.turuncu)),
              const SizedBox(width: 8),
              Expanded(child: _kiyilamaKutu('Gece büyük', kiyilama.gece, const Color(0xFFFFD7BF))),
            ]),
            const SizedBox(height: 6),
            Text('${kiyilama.neden} Şev ~${kiyilama.sev} m. Önerilen: ${kiyilama.takim}.',
                style: const TextStyle(color: Color(0xFFD6E9E6), fontSize: 12, height: 1.35)),
          ]),
        ),
        if ((sat?.comment(now.month) ?? '').isNotEmpty && Premium.panel('uydu') == PanelDurum.acik) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.satellite_alt_outlined, size: 15, color: Color(0xFFFFD54F)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(sat!.comment(now.month),
                  style: const TextStyle(color: Color(0xFFFFF3C4), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        // Hava / deniz ölçümleri
        Wrap(spacing: 10, runSpacing: 10, children: [
          _chip(Icons.air, 'Rüzgâr', '${r.windKmh?.round() ?? '-'} km/s ${r.windFrom}',
              y: Yorum.ruzgar(r.windKmh, r.windFrom)),
          _chip(Icons.waves, 'Dalga (6 sa. en fazla)',
              r.strait ? '${f.spot.shelter} içi' : (r.waveM == null ? '—' : '${r.waveM!.toStringAsFixed(1)} m (${r.effectiveWave.toStringAsFixed(1)} m)'),
              y: Yorum.dalga(r.strait || r.waveM == null ? null : r.effectiveWave, r.strait)),
          if (r.gustKmh != null) _chip(Icons.storm, 'Hamle', '${r.gustKmh!.round()} km/s', y: Yorum.hamle(r.gustKmh!)),
          if (r.rainDay != null)
            _chip(Icons.water_drop_outlined, 'Yağış (gün)', '${r.rainDay!.toStringAsFixed(r.rainDay! < 10 ? 1 : 0)} mm',
                y: Yorum.yagis(r.rainDay!)),
          _chip(Icons.thermostat, 'Su / Hava', '${r.seaC?.round() ?? '-'}° / ${r.airC?.round() ?? '-'}°',
              y: Yorum.suHava(r.seaC, r.airC)),
          _chip(Icons.speed, 'Basınç',
              r.pressure == null ? '—' : '${r.pressure!.round()} hPa ${trend == null ? '' : (trend < -0.8 ? '↘' : trend > 0.8 ? '↗' : '→')}',
              y: Yorum.basinc(r.pressure, trend)),
          if (fx.extraSea && r.currentKmh != null)
            _chip(Icons.swap_horiz, 'Akıntı', '${r.currentKmh!.toStringAsFixed(1)} km/s', y: Yorum.akinti(r.currentKmh!)),
          if (fx.extraSea && r.wavePeriod != null && r.wavePeriod! > 0)
            _chip(Icons.timelapse, 'Dalga periyodu', '${r.wavePeriod!.toStringAsFixed(1)} sn',
                y: Yorum.dalgaPeriyodu(r.wavePeriod!, r.effectiveWave)),
          if (fx.extraSea && r.cloud != null) _chip(Icons.cloud_outlined, 'Bulut', '%${r.cloud}', y: Yorum.bulut(r.cloud!)),
          if (sat?.sst != null && Premium.panel('uydu') == PanelDurum.acik)
            _chip(Icons.satellite_alt_outlined, 'Uydu su sıcaklığı (5 gün)',
                '${sat!.sst!.toStringAsFixed(1)}° ${sat!.sstChange5d == null ? '' : '(${sat!.sstChange5d! > 0 ? '+' : ''}${sat!.sstChange5d!.toStringAsFixed(1)}°)'}',
                y: Yorum.uyduSst(sat!.sst!, sat!.sstChange5d, now.month)),
          if (sat?.chl != null && Premium.panel('uydu') == PanelDurum.acik)
            _chip(Icons.grass_outlined, 'Klorofil (yem balığı)',
                '${sat!.chl!.toStringAsFixed(1)} mg/m³ ${sat!.chlChangePct == null ? '' : '(${sat!.chlChangePct! > 0 ? '+' : ''}%${sat!.chlChangePct})'}',
                y: Yorum.klorofil(sat!.chl!, sat!.chlChangePct)),
          if (catches.isNotEmpty)
            _chip(Icons.groups_outlined, 'Son 48 saat üye avı', '${catches.length} bildirim · ${catches.first.fish}',
                y: Yorum.uyeAvi(catches.length, catches.first.fish)),
          if (fx.modelConsensus && f.consensus != null && f.consensus!.count >= 2)
            _chip(Icons.fact_check_outlined, 'Model uyumu (${f.consensus!.count} model)',
                '${f.consensus!.level} · ort. ${f.consensus!.mean.round()} km/s',
                y: Yorum.modelUyumu(f.consensus!.level, f.consensus!.mean, f.consensus!.count)),
        ]),
        const SizedBox(height: 8),
        if (Moduller.app('olcum_yorum', uye: true)?.b('ipucu', true) ?? false)
        const Row(children: [
          Icon(Icons.touch_app_outlined, size: 14, color: Color(0x99FFFFFF)),
          SizedBox(width: 5),
          Expanded(
            child: Text('Değerlere dokun: ne anlama geldiğini ve balığın hangi mesafede olduğunu gör',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5)),
          ),
        ]),
        const SizedBox(height: 16),
        // En iyi saatler
        const Text('EN VERİMLİ SAATLER',
            style: TextStyle(color: Color(0xFFCFE3E0), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _window('Sabah', today?.sunrise, Icons.wb_twilight)),
          const SizedBox(width: 10),
          Expanded(child: _window('Akşam', today?.sunset, Icons.nights_stay_outlined)),
        ]),
        const SizedBox(height: 16),
        // 7 günlük tablo
        const Row(children: [
          Text('7 GÜNLÜK TAHMİN',
              style: TextStyle(color: Color(0xFFCFE3E0), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          Spacer(),
          Text('Ayrıntı için güne dokun', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5)),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < f.days.length; i++)
          Premium.gunAcik(i) ? _dayRow(f.days[i]) : _KilitliGun(child: _dayRow(f.days[i])),
        if (List.generate(f.days.length, Premium.gunAcik).contains(false))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: YukseltDugmesi(yazi: 'Tüm günleri aç — Yükselt')),
          ),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.phishing, color: Tide.turuncu, size: 16),
          SizedBox(width: 6),
          Text('KıyıdanAv · kiyidanav.com',
              style: TextStyle(color: Color(0xFFD7E6E3), fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      ]),
        ),
      ]),
    );
  }

  Widget _chip(IconData i, String k, String v, {OlcumYorum? y}) {
    // Panel → Modüller → Ölçüm açıklamaları kapalıysa kutular dokunulmaz
    final oy = Moduller.app('olcum_yorum', uye: true);
    if (oy == null) y = null;
    final cerceve = y != null && (oy?.b('cerceveRenk', true) ?? true);
    final kutu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: cerceve ? Border.all(color: tonRengi(y!.ton).withAlpha(190)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, color: const Color(0xFFD6E9E6), size: 16),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Color(0xFFCFE3E0), fontSize: 10.5)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ]),
        if (y != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.info_outline, color: Color(0x99FFFFFF), size: 13),
        ],
      ]),
    );
    final yorum = y;
    if (yorum == null) return kutu;
    return Builder(
      builder: (ctx) => Semantics(
        button: true,
        label: '$k açıklaması',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            switch (Premium.bilgi()) {
              case PanelDurum.acik:
                showOlcumSheet(ctx, yorum);
              case PanelDurum.kilitli:
                premiumSayfasi(ctx);
              case PanelDurum.gizli:
                break;
            }
          },
          child: kutu,
        ),
      ),
    );
  }

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

  /// Bugünün satırı rapor başlığıyla aynı puanı gösterir (başlıkta basınç, akıntı, uydu ve üye avları da var)
  Widget _dayRow(DayForecast d) => _DayRow(
      d: d,
      scoreColor: _scoreColor,
      skor: DateUtils.isSameDay(d.date, now) ? score : null);

  Widget _kiyilamaKutu(String baslik, String deger, Color renk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Flexible(child: Text(baslik, style: const TextStyle(color: Color(0xFFCFE3E0), fontSize: 10.5))),
        ]),
        Text(deger, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      ]);

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF2E8B57);
    if (s >= 60) return const Color(0xFFC98A1B);
    return const Color(0xFFB0413E);
  }
}

/// Premium'a ayrılmış gün: bulanık satır + kilit; dokununca Yükselt sayfası
class _KilitliGun extends StatelessWidget {
  final Widget child;
  const _KilitliGun({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => premiumSayfasi(context),
      child: Stack(alignment: Alignment.center, children: [
        IgnorePointer(
          child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: child),
        ),
        const Icon(Icons.lock_outline, color: Colors.white, size: 18),
      ]),
    );
  }
}

/// 7 günlük tahminde bir gün: hava simgesi + dokununca açılan kısa ayrıntı
class _DayRow extends StatefulWidget {
  final DayForecast d;
  final Color Function(int) scoreColor;
  /// Verilirse (bugün) bu puan gösterilir
  final int? skor;
  const _DayRow({required this.d, required this.scoreColor, this.skor});

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final s = widget.skor ??
        FishingScore.compute(d.date.add(const Duration(hours: 12)), windKmh: d.effectiveWind, waveM: d.waveMax, rainMm: d.rainSum);
    final w = WeatherLook.of(d.weatherCode);
    return Material(
      color: _open ? const Color(0x1FFFFFFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SizedBox(
                width: 72,
                child: Text('${d.date.day} ${ayAdlari[d.date.month].substring(0, 3)}\n${_gunler[d.date.weekday - 1]}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.25, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                  width: 22, height: 22, child: CustomPaint(painter: MoonPainter(d.date.add(const Duration(hours: 21))))),
              const SizedBox(width: 6),
              Icon(w.icon, color: w.color, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${d.windMax?.round() ?? '-'}/${d.gustMax?.round() ?? '-'} km/s · ${d.waveMax == null ? '—' : '${d.waveMax!.toStringAsFixed(1)} m'}${(d.rainSum ?? 0) >= 1 ? ' · ${d.rainSum!.round()} mm' : ''}',
                  style: const TextStyle(color: Color(0xFFD6E9E6), fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: widget.scoreColor(s), borderRadius: BorderRadius.circular(7)),
                child: Text('%$s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
              const SizedBox(width: 6),
              _FishRow(FishingScore.fishCount(s), size: 12),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _open ? _details(d, w, s) : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _details(DayForecast d, WeatherLook w, int s) {
    String deg(double? v) => v == null ? '-' : '${v.round()}°';
    final lines = <(IconData, String)>[
      (w.icon, '${w.label}${d.rainProb != null ? ' · yağış olasılığı %${d.rainProb}' : ''}'
          '${(d.rainSum ?? 0) >= 0.5 ? ' · ${d.rainSum!.toStringAsFixed(d.rainSum! < 10 ? 1 : 0)} mm' : ''}'),
      (Icons.thermostat, 'Sıcaklık ${deg(d.tempMin)} / ${deg(d.tempMax)}'),
      (Icons.air,
          'Rüzgâr ${d.windFrom.isEmpty ? '' : '${d.windFrom} '}${d.windMax?.round() ?? '-'} km/s, hamle ${d.gustMax?.round() ?? '-'} km/s'),
      if (d.waveMax != null) (Icons.waves, 'Dalga en fazla ${d.waveMax!.toStringAsFixed(1)} m'),
      (Icons.wb_twilight, 'Gün doğumu ${_saat(d.sunrise)} · batımı ${_saat(d.sunset)}'),
      (Icons.nightlight_round, Moon.phaseName(d.date.add(const Duration(hours: 21)))),
      (Icons.phishing, 'Av verimliliği %$s (${FishingScore.label(s)})'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (icon, text) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 15, color: const Color(0xFFFFD54F)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3))),
            ]),
          ),
      ]),
    );
  }
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

class _ReportData {
  final SpotForecast f;
  final List<CatchReport> catches;
  final SatInfo? sat;
  final MeraInfo? info; // kıyı kesiti (kıyılama hesabı için)
  const _ReportData(this.f, this.catches, this.sat, [this.info]);
}


/// İnternet yokken gösterilen kayıtlı raporun uyarısı (Çevrimdışı mod)
class CevrimdisiSerit extends StatelessWidget {
  const CevrimdisiSerit({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: Cevrimdisi.kullanilan,
      builder: (_, t, __) {
        if (t == null) return const SizedBox.shrink();
        final d = DateTime.now().difference(t);
        final once = d.inMinutes < 60 ? '${d.inMinutes} dk' : '${d.inHours} saat';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.cloud_off, color: Color(0xFFB7791F)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('İnternet yok: $once önce kaydedilen rapor gösteriliyor.',
                  style: const TextStyle(color: Color(0xFF6B4E00), fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      },
    );
  }
}
