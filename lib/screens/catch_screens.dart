import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api.dart';
import '../araclar.dart';
import '../app_state.dart';
import '../catches.dart';
import '../config.dart';
import '../hata.dart';
import '../mera.dart';
import '../models.dart';
import '../moduller.dart';
import '../overlays.dart';
import '../sea.dart';
import '../solunar.dart';
import '../theme.dart';
import '../web_page_screen.dart';

/// Yaygın kıyı balıkları (hızlı seçim); listede yoksa elle yazılır
const commonFish = [
  'Lüfer', 'Palamut', 'Çinekop', 'Sarıkanat', 'İstavrit', 'Levrek', 'Çipura', 'Kefal',
  'Mezgit', 'İzmarit', 'Karagöz', 'Sarpan', 'Kalamar', 'Barbunya', 'Zargana', 'Kolyoz',
];

/// Üyelik anahtarı: yoksa sitedeki oturumla (uygulama içi tarayıcı) doğrulanır.
/// Üye değilse veya giriş yapılmamışsa null döner.
Future<String?> ensureCatchToken(BuildContext context) async {
  final t = await CatchService.token();
  if (t != null) return t;
  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _MemberCheckScreen()));
}

/// Sitedeki oturumu okuyup anahtarı alan kısa ekran
class _MemberCheckScreen extends StatefulWidget {
  const _MemberCheckScreen();

  @override
  State<_MemberCheckScreen> createState() => _MemberCheckScreenState();
}

class _MemberCheckScreenState extends State<_MemberCheckScreen> {
  late final WebViewController _web;
  bool _needLogin = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Tide.zemin)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          if (_done || !url.contains('mobil-av.php')) return;
          try {
            final r = await _web.runJavaScriptReturningResult(
                "(document.getElementById('t')||{}).textContent||''");
            var t = '$r';
            if (t.startsWith('"')) t = jsonDecode(t) as String; // Android sonucu tırnaklı döndürür
            t = t.trim();
            if (!mounted) return;
            if (t.contains('.')) {
              _done = true;
              await CatchService.saveToken(t);
              await appState.setMember(true);
              if (mounted) Navigator.of(context).pop(t);
            } else {
              setState(() => _needLogin = true);
            }
          } catch (_) {
            if (mounted) setState(() => _needLogin = true);
          }
        },
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          return (u != null && u.scheme == 'https' && u.host.endsWith(AppConfig.siteHost))
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse('${AppConfig.siteUrl}${CatchService.sessionPath}'));
  }

  Future<void> _retry() async {
    setState(() => _needLogin = false);
    await _web.loadRequest(Uri.parse('${AppConfig.siteUrl}${CatchService.sessionPath}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Üyelik doğrulanıyor')),
      body: Stack(children: [
        Opacity(opacity: 0.01, child: WebViewWidget(controller: _web)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _needLogin
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, size: 44, color: Tide.turuncu),
                    const SizedBox(height: 12),
                    const Text('Av bildirmek için üye girişi yapmalısın.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                      onPressed: () async {
                        // Giriş sayfası açılır; başarılı girişte buraya döner ve anahtar otomatik alınır
                        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
                            builder: (_) => const WebPageScreen(
                                title: 'Giriş yap', route: 'account/login', popAfterLogin: true)));
                        if (ok == true && mounted) await _retry();
                      },
                      child: const Text('Giriş yap / Üye ol'),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Giriş yaptım, tekrar dene')),
                  ])
                : const Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: Tide.zeytin),
                    SizedBox(height: 14),
                    Text('Üyeliğin kontrol ediliyor…'),
                  ]),
          ),
        ),
      ]),
    );
  }
}

/// "Av bildir" formu
class CatchFormScreen extends StatefulWidget {
  final Spot spot;
  final String token;
  const CatchFormScreen({super.key, required this.spot, required this.token});

  /// Üye kontrolü yapıp formu açar
  static Future<void> open(BuildContext context, Spot spot) async {
    if (!Api.config.features.catchSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Av bildirimi şu an kapalı.')));
      return;
    }
    if (!appState.isMember) {
      showMemberPrompt(context, 'Av bildirmek');
      return;
    }
    try {
      final t = await ensureCatchToken(context);
      if (!context.mounted) return;
      if (t == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Üyeliğin doğrulanamadı. Hesabım › Giriş yap ile yeniden giriş yapıp tekrar dene.')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CatchFormScreen(spot: spot, token: t)));
    } catch (e) {
      Hata.goster(e);
    }
  }

  @override
  State<CatchFormScreen> createState() => _CatchFormScreenState();
}

class _CatchFormScreenState extends State<CatchFormScreen> {
  // Haritadan seçilen noktada bildirim en yakın kayıtlı meraya yazılır
  late Spot _spot = spots.firstWhere((s) => s.name == widget.spot.key, orElse: () => spots[5]);
  final _fish = TextEditingController();
  final _count = TextEditingController();
  final _kg = TextEditingController();
  final _bait = TextEditingController();
  final _note = TextEditingController();
  final _spotInfo = TextEditingController();
  final _insta = TextEditingController();
  final _boy = TextEditingController();
  final List<XFile> _photos = [];
  // Modüller: turnuva, "bu ürünle tutuldu", fotoğraftan tür tanıma
  String _turnuva = '';
  int _urunId = 0;
  String _urunAd = '';
  bool _tanimlaniyor = false;
  ModulCfg? get _turnuvaModul => Moduller.app('turnuva', uye: true);
  List<Map<String, dynamic>> get _turnuvalar =>
      _turnuvaModul == null ? const [] : aktifTurnuvalar(_turnuvaModul!.l('turnuvalar'), DateTime.now());
  Map<String, dynamic>? get _seciliTurnuva {
    for (final t in _turnuvalar) {
      if ('${t['ad']}' == _turnuva) return t;
    }
    return null;
  }
  DateTime _time = DateTime.now();
  bool _sending = false;
  bool _consent = false;
  // Modül: av bildirimine mesafe ve derinlik
  String _mesafe = '';
  String _derinlik = '';
  Future<SpotForecast?>? _hava;
  ModulCfg? get _mesafeModul => Moduller.app('bildirim_mesafe', uye: true);

  static const maxPhotos = 3;

  @override
  void initState() {
    super.initState();
    // Instagram hesabı bir kez yazılır, sonraki bildirimlerde hazır gelir
    CatchService.savedInstagram().then((v) {
      if (mounted && _insta.text.isEmpty && v.isNotEmpty) setState(() => _insta.text = v);
    });
    if (_mesafeModul?.b('havaKaydi', true) ?? false) _havaYukle();
  }

  void _havaYukle() {
    _hava = SeaService.fetchWeek(_spot).then<SpotForecast?>((f) => f).catchError((_) => null);
  }

  /// Bildirim anının havası (yalnız av "bugün" ve son birkaç saat içindeyse anlamlı)
  Future<Map<String, Object>> _havaKaydi() async {
    final m = _mesafeModul;
    if (m == null || !m.b('havaKaydi', true) || _hava == null) return const {};
    if (DateTime.now().difference(_time).inHours.abs() > 6) return const {};
    final f = await _hava!.timeout(const Duration(seconds: 4), onTimeout: () => null);
    if (f == null) return const {};
    final r = f.now;
    return {
      if (r.pressure != null) 'basinc': r.pressure!.toStringAsFixed(1),
      if (f.pressureTrend != null) 'egilim': f.pressureTrend!.toStringAsFixed(1),
      'ruzgar': r.effectiveWind.toStringAsFixed(0),
      if (!r.strait && r.waveM != null) 'dalga': r.effectiveWave.toStringAsFixed(1),
      if (r.cloud != null) 'bulut': '${r.cloud}',
      if (r.seaC != null) 'su': r.seaC!.toStringAsFixed(1),
      'ay': (Moon.illumination(_time) * 100).round(),
      'evre': Moon.phaseName(_time),
    };
  }

  @override
  void dispose() {
    for (final c in [_fish, _count, _kg, _bait, _note, _spotInfo, _insta, _boy]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource src) async {
    final left = maxPhotos - _photos.length;
    if (left <= 0) return;
    final picker = ImagePicker();
    try {
      if (src == ImageSource.camera) {
        final x = await picker.pickImage(source: src, maxWidth: 1800, imageQuality: 85);
        if (x != null) setState(() => _photos.add(x));
      } else {
        final xs = await picker.pickMultiImage(maxWidth: 1800, imageQuality: 85, limit: left > 1 ? left : null);
        if (xs.isNotEmpty) setState(() => _photos.addAll(xs.take(left)));
      }
    } catch (_) {
      _say('Fotoğraf seçilemedi.');
    }
  }

  /// Sitedeki ürünlerden seçim (Bu ürünle tutuldu)
  Future<void> _urunSec() async {
    final secilen = await showModalBottomSheet<ProductCard>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _UrunAramaSayfasi(),
    );
    if (secilen != null && mounted) setState(() { _urunId = secilen.id; _urunAd = secilen.name; });
  }

  /// İlk fotoğraftan tür önerisi + asgari boy uyarısı
  Future<void> _tani() async {
    if (_photos.isEmpty) return;
    setState(() => _tanimlaniyor = true);
    final r = await TaniSonuc.gonder(widget.token, _photos.first.path);
    if (!mounted) return;
    setState(() => _tanimlaniyor = false);
    if (!r.ok) {
      _say(r.hata.isEmpty ? 'Tanınamadı.' : r.hata);
      return;
    }
    final boy = double.tryParse(_boy.text.trim().replaceAll(',', '.')) ?? r.boyTahmini ?? 0;
    final kucuk = r.asgariBoy != null && boy > 0 && boy < r.asgariBoy!;
    await showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icon(kucuk ? Icons.warning_amber_rounded : Icons.set_meal_outlined, color: kucuk ? Tide.mercan : Tide.turuncu, size: 40),
        title: r.tur.isEmpty ? 'Tanınamadı' : (r.emin ? r.tur : '${r.tur}?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.tur.isNotEmpty) Text('Güven: %${r.guven}${r.emin ? '' : ' — emin değilim, listeden kontrol et'}'),
          if (r.alternatifler.isNotEmpty) Text('Belki: ${r.alternatifler.join(', ')}', style: const TextStyle(color: Tide.misina)),
          if (r.boyTahmini != null) Text('Fotoğraftan tahmini boy: ${r.boyTahmini!.toStringAsFixed(0)} cm'),
          if (r.aciklama.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(r.aciklama)),
          for (final u in r.uyarilar)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('⚠️ $u', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        actions: [
          if (r.tur.isNotEmpty)
            FilledButton(
              onPressed: () {
                setState(() {
                  _fish.text = r.tur;
                  if (_boy.text.trim().isEmpty && r.boyTahmini != null) _boy.text = r.boyTahmini!.toStringAsFixed(0);
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Türü kullan'),
            ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _say(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Avın günü (bugün / dün / 2 gün önce); saat korunur
  void _setDay(int daysAgo) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
    var v = DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
    if (v.isAfter(now)) v = now;
    setState(() => _time = v);
  }

  int get _daysAgo {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(_time.year, _time.month, _time.day)).inDays;
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
      helpText: 'AVLANDIĞIN SAAT',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null || !mounted) return;
    final now = DateTime.now();
    final v = DateTime(_time.year, _time.month, _time.day, t.hour, t.minute);
    if (v.isAfter(now)) {
      _say('İleri bir saat seçilemez. Saat şu ana ayarlandı.');
      setState(() => _time = now);
      return;
    }
    setState(() => _time = v);
  }

  Future<void> _send() async {
    final fish = _fish.text.trim();
    if (fish.isEmpty) {
      _say('Balık türünü seç veya yaz.');
      return;
    }
    final ig = CatchService.normalizeInstagram(_insta.text);
    if (ig == null) {
      _say(_insta.text.trim().isEmpty
          ? 'Instagram hesabını yaz (zorunlu).'
          : 'Instagram kullanıcı adı geçersiz. Sadece harf, rakam, nokta ve alt çizgi olabilir.');
      return;
    }
    if (!_consent) {
      _say('Instagram paylaşım iznini onaylaman gerekiyor.');
      return;
    }
    final boy = double.tryParse(_boy.text.trim().replaceAll(',', '.')) ?? 0;
    final tur = _seciliTurnuva;
    if (tur != null) {
      final kural = '${tur['kural'] ?? ''}';
      if (_photos.isEmpty) {
        _say('Turnuva için ölçüyü gösteren fotoğraf gerekli.');
        return;
      }
      if (kural == 'En uzun' && boy <= 0) {
        _say('Turnuva için balığın boyunu (cm) yaz.');
        return;
      }
      if (kural == 'En ağır' && (double.tryParse(_kg.text.trim().replaceAll(',', '.')) ?? 0) <= 0) {
        _say('Turnuva için ağırlığı (kg) yaz.');
        return;
      }
    }
    if ((_mesafeModul?.b('zorunlu') ?? false) && _mesafe.isEmpty) {
      _say('Balığı kaç metrede tuttuğunu seç.');
      return;
    }
    await CatchService.saveInstagram(ig);
    if (!mounted) return;
    setState(() => _sending = true);
    final (err, login, msg) = await CatchService.submit(
      token: widget.token,
      spot: _spot.name,
      fish: fish,
      count: int.tryParse(_count.text.trim()) ?? 0,
      kg: double.tryParse(_kg.text.trim().replaceAll(',', '.')) ?? 0,
      bait: _bait.text.trim(),
      note: _note.text.trim(),
      spotInfo: _spotInfo.text.trim(),
      instagram: ig,
      instagramConsent: _consent,
      time: _time,
      photoPaths: _photos.map((p) => p.path).toList(),
      distance: _mesafe,
      depth: _derinlik,
      weather: await _havaKaydi(),
      productId: _urunId,
      length: boy,
      tournament: _seciliTurnuva == null ? '' : _turnuva,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      _say(err);
      if (login) Navigator.of(context).pop();
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF1F8B4C), size: 40),
        title: 'Teşekkürler!',
        content: Text(msg ?? 'Av bildirimin alındı.'),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tamam'))],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Av bildir')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
              'Avın yönetici onayından sonra 48 saat boyunca meranın kartında görünür. Seçilen avlar @kiyidanav '
              'Instagram hesabında, senin hesabın etiketlenerek paylaşılır.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6D6C60))),
          const SizedBox(height: 14),
          _label('Mera'),
          DropdownButtonFormField<String>(
            initialValue: _spot.name,
            isExpanded: true,
            decoration: _dec(),
            items: [
              for (final side in Side.values.where((s) => s.public || appState.isMember))
                for (final s in spotsOf(side))
                  DropdownMenuItem(value: s.name, child: Text('${s.name} · ${side.label}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              final m = spots.where((s) => s.name == v);
              if (m.isNotEmpty) {
                setState(() => _spot = m.first);
                if (_mesafeModul?.b('havaKaydi', true) ?? false) _havaYukle();
              }
            },
          ),
          _label('Balık'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in commonFish)
              ChoiceChip(
                label: Text(f),
                selected: _fish.text == f,
                selectedColor: Tide.somon,
                onSelected: (_) => setState(() => _fish.text = f),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _fish, maxLength: 40, decoration: _dec(hint: 'Listede yoksa yaz'), onChanged: (_) => setState(() {})),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Adet'),
                TextField(controller: _count, keyboardType: TextInputType.number, decoration: _dec(hint: 'Örn. 3')),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Toplam kg (isteğe bağlı)'),
                TextField(
                    controller: _kg,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec(hint: 'Örn. 1,5')),
              ]),
            ),
          ]),
          _label('Boy (cm, isteğe bağlı)'),
          TextField(
              controller: _boy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(hint: 'Örn. 32')),
          _label('Yem / teknik'),
          TextField(controller: _bait, maxLength: 80, decoration: _dec(hint: 'Örn. maket balık, LRF silikon, çapari')),
          if (Moduller.app('bu_urunle', uye: true) != null) ...[
            _label('Kullandığın ürün (isteğe bağlı)'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Tide.zeytinKoyu,
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: _urunSec,
              icon: const Icon(Icons.inventory_2_outlined, color: Tide.turuncu),
              label: Row(children: [
                Expanded(
                    child: Text(_urunId > 0 ? _urunAd : 'KıyıdanAv\'dan aldığın ürünü seç',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (_urunId > 0)
                  InkWell(onTap: () => setState(() { _urunId = 0; _urunAd = ''; }), child: const Icon(Icons.close, size: 18)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Onaylanırsa avın, ürün sayfasındaki "Bu ürünle tutuldu" bölümünde görünür.',
                  style: TextStyle(fontSize: 12, color: Tide.misina)),
            ),
          ],
          if (_turnuvalar.isNotEmpty) ...[
            _label('Turnuvaya katıl (isteğe bağlı)'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in _turnuvalar)
                ChoiceChip(
                  avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: Text('${t['ad']}'),
                  selected: _turnuva == '${t['ad']}',
                  selectedColor: Tide.somon,
                  onSelected: (v) => setState(() {
                    _turnuva = v ? '${t['ad']}' : '';
                    final tur = '${t['tur'] ?? ''}'.trim();
                    if (v && tur.isNotEmpty) _fish.text = tur;
                  }),
                ),
            ]),
            if (_seciliTurnuva != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  'Kural: ${_seciliTurnuva!['kural'] ?? ''}. '
                  '${_turnuvaModul!.b('olcuKarti', true) ? 'Balığı ölçü kartı/cetvelle birlikte fotoğrafla' : 'Balığı fotoğrafla'}'
                  '${_turnuvaModul!.s('kod').isNotEmpty ? ' ve fotoğrafta bugünün kodunu göster: ${gununKodu(_turnuvaModul!.s('kod'), DateTime.now())}' : ''}.'
                  '${_turnuvaModul!.b('onay', true) ? ' Onaydan sonra sıralamaya girer.' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          if (_mesafeModul != null) ...[
            _label('Kaç metrede tuttun?${_mesafeModul!.b('zorunlu') ? '' : ' (isteğe bağlı)'}'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in _mesafeModul!.l('mesafeler'))
                ChoiceChip(
                  label: Text('${r['ad'] ?? ''}'),
                  selected: _mesafe == '${r['ad'] ?? ''}',
                  selectedColor: Tide.somon,
                  onSelected: (v) => setState(() => _mesafe = v ? '${r['ad'] ?? ''}' : ''),
                ),
            ]),
            _label('Hangi derinlikte?'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in _mesafeModul!.l('derinlikler'))
                ChoiceChip(
                  label: Text('${r['ad'] ?? ''}'),
                  selected: _derinlik == '${r['ad'] ?? ''}',
                  selectedColor: Tide.somon,
                  onSelected: (v) => setState(() => _derinlik = v ? '${r['ad'] ?? ''}' : ''),
                ),
            ]),
            if (_mesafeModul!.b('havaKaydi', true))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Bildirim anının havası (basınç, rüzgâr, bulut, ay) otomatik eklenir.',
                    style: TextStyle(fontSize: 12, color: Tide.misina)),
              ),
          ],
          _label('Mera bilgisi (isteğe bağlı)'),
          TextField(
              controller: _spotInfo,
              maxLength: 300,
              maxLines: 3,
              decoration: _dec(hint: 'Dip yapısı, derinlik, akıntı, ulaşım… Örn. taşlık dip, 4-5 m, mendirek ucu')),
          _label('Av günü ve saati'),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final (i, t) in const [(0, 'Bugün'), (1, 'Dün'), (2, '2 gün önce')])
              ChoiceChip(
                label: Text(t),
                selected: _daysAgo == i,
                selectedColor: Tide.somon,
                onSelected: (_) => _setDay(i),
              ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Tide.zeytinKoyu,
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Tide.turuncu),
            ),
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule, color: Tide.turuncu),
            label: Row(children: [
              Text('Saat ${_two(_time.hour)}:${_two(_time.minute)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Text('Değiştir', style: TextStyle(color: Tide.turuncu, fontWeight: FontWeight.w700)),
              const Icon(Icons.edit, size: 16, color: Tide.turuncu),
            ]),
          ),
          _label('Not (isteğe bağlı)'),
          TextField(controller: _note, maxLength: 300, maxLines: 3, decoration: _dec(hint: 'Hava, akıntı, saat… kısa bir not')),
          _label('Fotoğraflar (en fazla $maxPhotos)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(_photos[i].path), width: 96, height: 96, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: InkWell(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 15, color: Colors.white)),
                  ),
                ),
              ]),
            if (_photos.length < maxPhotos) ...[
              _photoButton(Icons.photo_camera_outlined, 'Kamera', () => _addPhoto(ImageSource.camera)),
              _photoButton(Icons.photo_library_outlined, 'Galeri', () => _addPhoto(ImageSource.gallery)),
            ],
          ]),
          if (Moduller.app('tur_tanima', uye: true) != null && _photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Tide.turuncu, side: const BorderSide(color: Tide.turuncu)),
                onPressed: _tanimlaniyor ? null : _tani,
                icon: _tanimlaniyor
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_tanimlaniyor ? 'Bakıyorum…' : 'Fotoğraftan türü tanı'),
              ),
            ),
          const SizedBox(height: 6),
          const Text('Fotoğraflardaki konum bilgisi sunucuda silinir. Yüz ve plaka içeren fotoğraf göndermemeni öneririz.',
              style: TextStyle(fontSize: 12, color: Color(0xFF77766A))),
          _label('Instagram hesabın (zorunlu)'),
          TextField(
            controller: _insta,
            maxLength: 60,
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: _dec(hint: 'kullaniciadi').copyWith(
              prefixIcon: const Icon(Icons.alternate_email, size: 20),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _consent = !_consent),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(
                value: _consent,
                activeColor: Tide.turuncu,
                onChanged: (v) => setState(() => _consent = v ?? false),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Avım onaylanırsa fotoğraflarım ve av bilgilerim @kiyidanav Instagram hesabında, '
                    'Instagram hesabım etiketlenerek paylaşılabilir.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Tide.turuncu, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Gönderiliyor…' : 'Onaya gönder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoButton(IconData icon, String text, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD9D5C7)),
            color: Colors.white,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Tide.zeytinKoyu),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}

/// Mera Bilgisi'ndeki "Bu merada son avlar" kartı + "Av bildir" düğmesi
class SpotCatchesCard extends StatefulWidget {
  final Spot spot;
  const SpotCatchesCard({super.key, required this.spot});

  @override
  State<SpotCatchesCard> createState() => _SpotCatchesCardState();
}

class _SpotCatchesCardState extends State<SpotCatchesCard> {
  late Future<List<CatchReport>> _f = CatchService.forSpot(widget.spot.key);

  @override
  void didUpdateWidget(SpotCatchesCard old) {
    super.didUpdateWidget(old);
    if (old.spot.key != widget.spot.key) _f = CatchService.forSpot(widget.spot.key);
  }

  Future<void> _report() async {
    await CatchFormScreen.open(context, widget.spot);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: FutureBuilder<List<CatchReport>>(
        future: _f,
        builder: (context, snap) {
          final fx = Api.config.features;
          final list = fx.catchList ? (snap.data ?? const <CatchReport>[]) : const <CatchReport>[];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (fx.catchList) Row(children: [
              const Icon(Icons.set_meal, color: Tide.turuncu),
              const SizedBox(width: 8),
              Expanded(
                child: Text(list.isEmpty ? 'Bu merada son 48 saatte bildirilen av yok' : 'Bu merada son avlar',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (list.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Tide.turuncu),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatchesFeedScreen())),
                  child: const Text('Tümü'),
                ),
            ]),
            for (final c in list.take(3)) CatchTile(c),
            if (fx.catchList && fx.catchSubmit) const SizedBox(height: 8),
            if (fx.catchSubmit) OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Tide.zeytinKoyu,
                side: const BorderSide(color: Tide.turuncu),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _report,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const AvBildirYazisi(),
            ),
          ]);
        },
      ),
    );
  }
}

/// Tek bir av satırı (fotoğraf küçük resmi + bilgiler)
class CatchTile extends StatelessWidget {
  final CatchReport c;
  final bool showSpot;
  const CatchTile(this.c, {super.key, this.showSpot = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showCatchSheet(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: c.photos.isNotEmpty
                  ? Image.network(c.photos.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                  : _ph(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.fish}${c.amount.isNotEmpty ? ' · ${c.amount}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              Text([if (showSpot) c.spot, if (c.bait.isNotEmpty) c.bait].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
              Text('${c.name} · ${c.ago()}', style: const TextStyle(fontSize: 12, color: Tide.misina)),
            ]),
          ),
          if (c.photos.length > 1)
            Text('+${c.photos.length - 1} foto', style: const TextStyle(fontSize: 11.5, color: Tide.misina)),
        ]),
      ),
    );
  }

  Widget _ph() => Container(
      color: const Color(0xFFF1EFE6), child: const Icon(Icons.set_meal, color: Tide.misina));
}

void showCatchSheet(BuildContext context, CatchReport c) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${c.fish} · ${c.spot}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            CloseX(onTap: () => Navigator.of(ctx).pop()),
          ]),
          const SizedBox(height: 4),
          Text([if (c.amount.isNotEmpty) c.amount, c.name, c.ago()].join(' · '),
              style: const TextStyle(color: Color(0xFF6D6C60))),
          if (c.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PageView(children: [
                for (final p in c.photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(child: Image.network(p, fit: BoxFit.cover))),
                  ),
              ]),
            ),
          ],
          if (c.bait.isNotEmpty) ...[const SizedBox(height: 12), Text('Yem / teknik: ${c.bait}')],
          if (c.spotInfo.isNotEmpty) ...[const SizedBox(height: 6), Text('Mera bilgisi: ${c.spotInfo}')],
          if (c.note.isNotEmpty) ...[const SizedBox(height: 6), Text(c.note)],
          if (c.instagram.isNotEmpty || c.igLink.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              if (c.instagram.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.alternate_email, size: 16),
                  label: Text(c.instagram),
                  onPressed: () => launchUrl(Uri.https('www.instagram.com', '/${c.instagram}/'),
                      mode: LaunchMode.externalApplication),
                ),
              if (c.igLink.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text('Instagram paylaşımı'),
                  onPressed: () => launchUrl(Uri.parse(c.igLink), mode: LaunchMode.externalApplication),
                ),
            ]),
          ],
        ]),
      ),
    ),
  );
}

/// Tüm meralardaki son avlar
class CatchesFeedScreen extends StatefulWidget {
  /// true: süre sınırı olmadan en yeni avlar (Keşfet › Balıkçılarımızın son avları › Tümü)
  final bool son;
  const CatchesFeedScreen({super.key, this.son = false});

  @override
  State<CatchesFeedScreen> createState() => _CatchesFeedScreenState();
}

class _CatchesFeedScreenState extends State<CatchesFeedScreen> {
  late Future<List<CatchReport>> _f = _getir();
  Future<List<CatchReport>> _getir() => widget.son ? CatchService.latest() : CatchService.recent(force: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.son ? 'Balıkçılarımızın son avları' : 'Son 48 saatin avları')),
      body: RefreshIndicator(
        color: Tide.turuncu,
        onRefresh: () async {
          setState(() => _f = _getir());
          await _f.catchError((_) => const <CatchReport>[]);
        },
        child: FutureBuilder<List<CatchReport>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tide.zeytin));
            }
            final list = snap.data ?? const <CatchReport>[];
            if (list.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(widget.son ? 'Henüz onaylanmış av bildirimi yok. İlk bildiren sen ol!' : 'Son 48 saatte onaylanmış av bildirimi yok. İlk bildiren sen ol!',
                      textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => CatchTile(list[i], showSpot: true),
            );
          },
        ),
      ),
    );
  }
}

/// Keşfet'te: son 48 saatin onaylı avlarından yatay şerit (av yoksa görünmez)
class RecentCatchesStrip extends StatefulWidget {
  const RecentCatchesStrip({super.key});

  @override
  State<RecentCatchesStrip> createState() => _RecentCatchesStripState();
}

class _RecentCatchesStripState extends State<RecentCatchesStrip> {
  late final Future<List<CatchReport>> _f = Api.config.features.catchList
      ? CatchService.latest().catchError((_) => CatchService.recent()).catchError((_) => const <CatchReport>[])
      : Future.value(const <CatchReport>[]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatchReport>>(
      future: _f,
      builder: (context, snap) {
        final list = snap.data ?? const <CatchReport>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Row(children: [
                const Icon(Icons.groups_outlined, color: Tide.turuncu, size: 20),
                const SizedBox(width: 6),
                const Expanded(
                    child: Text('Balıkçılarımızın son avları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Tide.turuncu),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatchesFeedScreen(son: true))),
                  child: const Text('Tümü'),
                ),
              ]),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: list.length > 12 ? 12 : list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showCatchSheet(context, c),
                    child: Container(
                      width: 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6E2D6)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          height: 84,
                          width: double.infinity,
                          child: c.photos.isNotEmpty
                              ? Image.network(c.photos.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1EFE6)))
                              : Container(
                                  color: const Color(0xFFF1EFE6),
                                  child: const Icon(Icons.set_meal, color: Tide.misina, size: 32)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                          child: Text(c.fish,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('${c.spot} · ${c.ago()}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Tide.misina)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Av bildiriminde "kullandığın ürün" araması
class _UrunAramaSayfasi extends StatefulWidget {
  const _UrunAramaSayfasi();

  @override
  State<_UrunAramaSayfasi> createState() => _UrunAramaSayfasiState();
}

class _UrunAramaSayfasiState extends State<_UrunAramaSayfasi> {
  final _q = TextEditingController();
  List<ProductCard> _l = const [];
  bool _yukleniyor = false;
  String _hata = '';

  Future<void> _ara() async {
    final q = _q.text.trim();
    if (q.length < 2) return;
    setState(() { _yukleniyor = true; _hata = ''; });
    try {
      final r = await Api.search(q);
      if (mounted) setState(() => _l = r.items);
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _ara(),
              decoration: InputDecoration(
                hintText: 'Ürün adı (ör. maket, jig, kamış)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _ara),
              ),
            ),
          ),
          if (_yukleniyor) const LinearProgressIndicator(minHeight: 2),
          if (_hata.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_hata)),
          Expanded(
            child: ListView.builder(
              itemCount: _l.length,
              itemBuilder: (_, i) {
                final p = _l[i];
                return ListTile(
                  leading: SizedBox(width: 48, height: 48, child: p.image == null ? const Icon(Icons.image_outlined) : Image.network(p.image!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))),
                  title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}


/// "Av bildir · KıyıdanAv İG ve KıyıdanPaylaş'ta paylaş" — KıyıdanPaylaş her yerde Lobster yazı tipiyle
class AvBildirYazisi extends StatelessWidget {
  final Color? renk;
  const AvBildirYazisi({super.key, this.renk});

  @override
  Widget build(BuildContext context) {
    final r = renk ?? DefaultTextStyle.of(context).style.color;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Av bildir', style: TextStyle(fontWeight: FontWeight.w800, color: r)),
        TextSpan(text: '  ·  KıyıdanAv İG ve ', style: TextStyle(fontSize: 12.5, color: r)),
        TextSpan(text: 'KıyıdanPaylaş', style: TextStyle(fontFamily: 'Lobster', fontSize: 15.5, color: r)),
        TextSpan(text: "'ta paylaş", style: TextStyle(fontSize: 12.5, color: r)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
