import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_state.dart';
import 'catches.dart';
import 'overlays.dart';
import 'theme.dart';
import 'topluluk_api.dart';

/// Yuvarlak profil fotoğrafı (yoksa adın baş harfi)
class Avatar extends StatelessWidget {
  final String url;
  final String ad;
  final double boy;
  const Avatar({super.key, required this.url, required this.ad, this.boy = 40});

  @override
  Widget build(BuildContext context) {
    final harf = ad.trim().isEmpty ? '?' : ad.trim().substring(0, 1).toUpperCase();
    return Container(
      width: boy,
      height: boy,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Tide.derinAcik,
        border: Border.all(color: Colors.white, width: 1.5),
        image: url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(harf, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: boy * 0.42))
          : null,
    );
  }
}

const kamisTurleri = ['Spin', 'LRF', 'Surfcasting', 'Tekne', 'Bot'];

const iller = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın',
  'Balıkesir', 'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı',
  'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
  'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars',
  'Kastamonu', 'Kayseri', 'Kilis', 'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa',
  'Mardin', 'Mersin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Şanlıurfa', 'Siirt',
  'Sinop', 'Şırnak', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak',
];

/// Balıkçı profili (yaş, kamış türü, il, ilçe). İlk açılışta bir kez sorulur; üye olunca üyeliğe de bağlanır.
class ProfilFormu {
  static const _kayitKey = 'profil_v1'; // "yas|Spin,LRF|İl|İlçe"
  static const _uyeGonderildiKey = 'profil_uye_gonderildi_v1';
  static const _sorulduKey = 'profil_soruldu_v1';
  static const _cihazKey = 'cihaz_kimlik_v1';

  static Future<String> _cihaz(SharedPreferences p) async {
    var c = p.getString(_cihazKey) ?? '';
    if (c.length < 16) {
      final r = math.Random.secure();
      c = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString(_cihazKey, c);
    }
    return c;
  }

  /// Uygulamanın ilk açılışında bir kez (panelde kapalıysa hiç)
  static Future<void> ilkAcilis(BuildContext context) async {
    if (!Api.config.features.profilFormu) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_sorulduKey) ?? false) {
      await uyeyeBagla();
      return;
    }
    await p.setBool(_sorulduKey, true);
    if (!context.mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const _ProfilDialog());
  }

  /// Üye girişinden sonra: yerelde kayıtlı form üyeye bağlı olarak bir kez daha gönderilir
  static Future<void> uyeyeBagla() async {
    try {
      final p = await SharedPreferences.getInstance();
      final k = p.getString(_kayitKey);
      if (k == null || (p.getBool(_uyeGonderildiKey) ?? false) || await CatchService.token() == null) return;
      final x = k.split('|');
      if (x.length < 4) return;
      await _gonder(int.tryParse(x[0]) ?? 0, x[1].split(','), x[2], x[3]);
      await p.setBool(_uyeGonderildiKey, true);
    } catch (_) {}
  }

  static Future<void> _gonder(int yas, List<String> kamis, String il, String ilce, {String instagram = ''}) async {
    final p = await SharedPreferences.getInstance();
    await Topluluk.gonder('profil_kaydet', {
      'yas': '$yas',
      'il': il,
      'ilce': ilce,
      'cihaz': await _cihaz(p),
      'platform': Topluluk.platform,
      if (instagram.isNotEmpty) 'instagram': instagram,
    }, diziler: kamis);
  }

  static Future<void> kaydet(int yas, List<String> kamis, String il, String ilce, {String instagram = ''}) async {
    await _gonder(yas, kamis, il, ilce, instagram: instagram);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kayitKey, '$yas|${kamis.join(',')}|$il|$ilce');
    if (await CatchService.token() != null) await p.setBool(_uyeGonderildiKey, true);
  }

  static Future<(int, List<String>, String, String)?> yerel() async {
    final k = (await SharedPreferences.getInstance()).getString(_kayitKey);
    final x = k?.split('|') ?? const [];
    if (x.length < 4) return null;
    return (int.tryParse(x[0]) ?? 0, x[1].split(',').where((e) => e.isNotEmpty).toList(), x[2], x[3]);
  }
}

/// Yaş, kamış türü (çoklu), il, ilçe formu — ilk açılış penceresi ve profil sayfası ortak
class ProfilAlanlari extends StatefulWidget {
  final int yas;
  final List<String> kamis;
  final String il;
  final String ilce;
  final String kaydetYazisi;
  final Future<void> Function(int yas, List<String> kamis, String il, String ilce) onKaydet;
  const ProfilAlanlari(
      {super.key,
      this.yas = 0,
      this.kamis = const [],
      this.il = '',
      this.ilce = '',
      this.kaydetYazisi = 'Kaydet',
      required this.onKaydet});

  @override
  State<ProfilAlanlari> createState() => _ProfilAlanlariState();
}

class _ProfilAlanlariState extends State<ProfilAlanlari> {
  late final _yas = TextEditingController(text: widget.yas > 0 ? '${widget.yas}' : '');
  late final _ilce = TextEditingController(text: widget.ilce);
  late final Set<String> _kamis = {...widget.kamis};
  late String _il = widget.il;
  String? _hata;
  bool _kaydediyor = false;

  @override
  void dispose() {
    _yas.dispose();
    _ilce.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final yas = int.tryParse(_yas.text.trim()) ?? 0;
    String? h;
    if (yas < 18 || yas > 99) h = 'Yaşını 18–99 arasında yaz.';
    if (h == null && _kamis.isEmpty) h = 'En az bir kamış türü seç.';
    if (h == null && _il.isEmpty) h = 'Avlandığın ili seç.';
    if (h == null && _ilce.text.trim().isEmpty) h = 'Avlandığın ilçeyi yaz.';
    if (h != null) {
      setState(() => _hata = h);
      return;
    }
    setState(() {
      _hata = null;
      _kaydediyor = true;
    });
    try {
      await widget.onKaydet(yas, kamisTurleri.where(_kamis.contains).toList(), _il, _ilce.text.trim());
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dek(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _yas, keyboardType: TextInputType.number, maxLength: 2, decoration: dek('Yaşın').copyWith(counterText: '')),
      const SizedBox(height: 12),
      const Text('Kullandığın kamış türü (birden fazla seçebilirsin)', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final k in kamisTurleri)
          FilterChip(
            label: Text(k),
            selected: _kamis.contains(k),
            selectedColor: Tide.somon,
            onSelected: (v) => setState(() => v ? _kamis.add(k) : _kamis.remove(k)),
          ),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: iller.contains(_il) ? _il : null,
        isExpanded: true,
        decoration: dek('Avlandığın il'),
        items: [for (final i in iller) DropdownMenuItem(value: i, child: Text(i))],
        onChanged: (v) => setState(() => _il = v ?? ''),
      ),
      const SizedBox(height: 12),
      TextField(controller: _ilce, textCapitalization: TextCapitalization.words, decoration: dek('Avlandığın ilçe')),
      if (_hata != null) ...[
        const SizedBox(height: 8),
        Text(_hata!, style: const TextStyle(color: Tide.mercan, fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 14),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _kaydediyor ? null : _kaydet,
        child: Text(_kaydediyor ? 'Kaydediliyor…' : widget.kaydetYazisi),
      ),
    ]);
  }
}

class _ProfilDialog extends StatelessWidget {
  const _ProfilDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: Alignment.topRight, child: CloseX(onTap: () => Navigator.of(context).pop())),
          const Text('Seni biraz tanıyalım', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Mera önerilerini sana göre ayarlamak için. Yaklaşık 20 saniye sürer.',
              style: TextStyle(color: Color(0xFF6B6A60))),
          const SizedBox(height: 14),
          ProfilAlanlari(onKaydet: (yas, kamis, il, ilce) async {
            await ProfilFormu.kaydet(yas, kamis, il, ilce);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgilerin kaydedildi. Rastgele gelsin! 🎣')));
            }
          }),
        ]),
      ),
    );
  }
}

/// Profilim: fotoğraf, Instagram hesabı ve balıkçı bilgileri (Fishkrok ve Badimi bul'da görünür)
class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  static Future<void> ac(BuildContext context) async {
    if (!await Topluluk.uyeHazir(context, 'Profil') || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilEkrani()));
  }

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  Map<String, dynamic>? _p;
  String? _hata;
  bool _fotoYukleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Topluluk.al('profil');
      if (mounted) setState(() => _p = j);
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _foto(ImageSource kaynak) async {
    final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1200, imageQuality: 85);
    if (x == null) return;
    setState(() => _fotoYukleniyor = true);
    try {
      final j = await Topluluk.gonder('avatar', const {}, dosya: x.path);
      setState(() => _p = {...?_p, 'avatar': j['avatar']});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _fotoYukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: p == null
          ? Center(child: _hata != null ? Text(_hata!) : const CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(18), children: [
              Center(
                child: Stack(children: [
                  Avatar(url: '${p['avatar'] ?? ''}', ad: '${p['ad'] ?? ''}', boy: 108),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: PopupMenuButton<ImageSource>(
                      tooltip: 'Profil fotoğrafını değiştir',
                      onSelected: _foto,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: ImageSource.camera, child: Text('Fotoğraf çek')),
                        PopupMenuItem(value: ImageSource.gallery, child: Text('Galeriden seç')),
                      ],
                      child: CircleAvatar(
                        backgroundColor: Tide.turuncu,
                        child: _fotoYukleniyor
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.photo_camera, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Center(child: Text('${p['ad'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              const Center(
                child: Text('Fotoğrafın KıyıdanPaylaş ve Badimi bul\'da adının yanında görünür.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6A60))),
              ),
              const SizedBox(height: 18),
              ProfilAlanlari(
                yas: tIntN(p['yas']) ?? 0,
                kamis: p['kamis'] is List ? (p['kamis'] as List).map((e) => '$e').toList() : '${p['kamis'] ?? ''}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                il: '${p['il'] ?? ''}',
                ilce: '${p['ilce'] ?? ''}',
                onKaydet: (yas, kamis, il, ilce) async {
                  await ProfilFormu.kaydet(yas, kamis, il, ilce);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profilin güncellendi.')));
                  }
                },
              ),
              if (!appState.isMember) const SizedBox.shrink(),
            ]),
    );
  }
}
