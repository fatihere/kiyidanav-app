import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'badi.dart';
import 'profil.dart';
import 'screens/catch_screens.dart';
import 'sea_card.dart';
import 'share.dart';
import 'theme.dart';
import 'topluluk_api.dart';

// =====================================================================
// Marka: logo (kanca + balık) ve Lobster yazı tipi
// =====================================================================
const fishkrokKoyu = Color(0xFF145A71);
const fishkrokAcik = Color(0xFF3FB6D0);

class FishkrokLogo extends StatelessWidget {
  final double boy;
  final Color? kanca; // eski çizim logodan kalan parametre (artık kullanılmıyor)
  const FishkrokLogo({super.key, this.boy = 36, this.kanca});

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Image.asset('assets/brand/logo.png',
            width: boy,
            height: boy,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                  width: boy,
                  height: boy,
                  color: Tide.turuncu,
                  alignment: Alignment.center,
                  child: Icon(Icons.set_meal, color: Colors.white, size: boy * 0.55),
                )),
      );
}

/// "KıyıdanPaylaş" yazısı — uygulamanın her yerinde Lobster
class FishkrokYazi extends StatelessWidget {
  final double boy;
  final Color renk;
  const FishkrokYazi({super.key, this.boy = 20, this.renk = fishkrokKoyu});

  @override
  Widget build(BuildContext context) =>
      Text('KıyıdanPaylaş', maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
          style: TextStyle(fontFamily: 'Lobster', fontSize: boy, color: renk, height: 1.1));
}

/// Logo + altında yazı
class FishkrokMarka extends StatelessWidget {
  final double boy;
  const FishkrokMarka({super.key, this.boy = 30});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        FishkrokLogo(boy: boy),
        FishkrokYazi(boy: boy * 0.5),
      ]);
}

// =====================================================================
// Veri
// =====================================================================
class FkYorum {
  final int id;
  final String ad;
  final String metin;
  final bool benim;
  const FkYorum(this.id, this.ad, this.metin, this.benim);
  factory FkYorum.fromJson(Map j) => FkYorum(tInt(j['id']), '${j['ad'] ?? ''}', '${j['metin'] ?? ''}', j['benim'] == true);
}

class FkGonderi {
  final String id, ad, instagram, avatar, mera, balik, miktar, yem, not, meraBilgi, saat;
  final List<String> fotolar;
  int begeni;
  bool begendim;
  double puan;
  int puanSayi;
  int puanim;
  int yorumSayi;
  List<FkYorum> yorumlar;

  FkGonderi.fromJson(Map j)
      : id = '${j['id'] ?? ''}',
        ad = '${j['ad'] ?? ''}',
        instagram = '${j['instagram'] ?? ''}',
        avatar = '${j['avatar'] ?? ''}'.startsWith('https://') ? '${j['avatar']}' : '',
        mera = '${j['mera'] ?? ''}',
        balik = '${j['balik'] ?? ''}',
        miktar = '${j['miktar'] ?? ''}',
        yem = '${j['yem'] ?? ''}',
        not = '${j['not'] ?? ''}',
        meraBilgi = '${j['mera_bilgi'] ?? ''}',
        saat = '${j['saat'] ?? ''}',
        fotolar = ((j['fotolar'] as List?) ?? const []).map((e) => '$e').where((u) => u.startsWith('https://')).take(3).toList(),
        begeni = tInt(j['begeni']),
        begendim = j['begendim'] == true,
        puan = tDouble(j['puan']),
        puanSayi = tInt(j['puan_sayi']),
        puanim = tInt(j['puanim']),
        yorumSayi = tInt(j['yorum_sayi']),
        yorumlar = ((j['yorumlar'] as List?) ?? const []).whereType<Map>().map(FkYorum.fromJson).toList();

  String get kim => instagram.isNotEmpty ? '@$instagram' : ad;
}

/// Yorum kuralı (sunucuda da aynısı uygulanır): telefon, Instagram hesabı ve bağlantı paylaşılamaz
String? yorumDenetle(String s) {
  final sade = s.replaceAll(RegExp(r'[\s().\-/]'), '');
  if (RegExp(r'(\+?90|0)?5\d{9}').hasMatch(sade) || RegExp(r'\d{10,}').hasMatch(sade)) {
    return 'Yorumlarda telefon numarası paylaşılamaz.';
  }
  if (RegExp(r'(^|[\s(])@[\p{L}0-9._]{2,}|instagram|insta\s*[:=]|\big\s*[:=]', caseSensitive: false, unicode: true).hasMatch(s)) {
    return 'Yorumlarda Instagram hesabı paylaşılamaz.';
  }
  if (RegExp(r'https?://|www\.|\b[\p{L}0-9-]+\.(com|net|org|tr|me|ly|io|app|link|co|info|xyz|shop)\b', caseSensitive: false, unicode: true)
      .hasMatch(s)) {
    return 'Yorumlarda bağlantı (link) paylaşılamaz.';
  }
  return null;
}

/// Paylaşım metni: KıyıdanAv bilgileri her zaman metnin bir parçası
/// 1.13.1: bağlantı metnin içinde açık adres olarak değil, "KıyıdanPaylaş avı" adıyla verilir
/// (bağlantı sona eklenir; WhatsApp / Telegram / iMessage onu "KıyıdanPaylaş avı" başlıklı kart olarak gösterir).
String fishkrokPaylasimMetni(FkGonderi g, String link) => '🎣 ${g.balik}${g.miktar.isNotEmpty ? ' (${g.miktar})' : ''}\n'
    '${g.kim} KıyıdanPaylaş\'ta yeni bir av paylaştı.\n'
    'KıyıdanAv · olta, makine ve kıyı balıkçılığı ekipmanları\n'
    '${link.isEmpty ? '' : '\nKıyıdanPaylaş avı 👇\n$link'}';

// =====================================================================
// Akış ekranı (alt sekme)
// =====================================================================
class FishkrokEkrani extends StatefulWidget {
  const FishkrokEkrani({super.key});

  @override
  State<FishkrokEkrani> createState() => _FishkrokEkraniState();
}

class _FishkrokEkraniState extends State<FishkrokEkrani> {
  final List<FkGonderi> _liste = [];
  int _sayfa = 0;
  bool _devam = true;
  bool _yukleniyor = false;
  String? _hata;
  bool _kapali = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({bool bastan = false}) async {
    if (_yukleniyor || (!_devam && !bastan)) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
      if (bastan) {
        _liste.clear();
        _sayfa = 0;
        _devam = true;
      }
    });
    try {
      final j = await Topluluk.al('fk_akis', {'sayfa': '${_sayfa + 1}'});
      if (!mounted) return;
      setState(() {
        _kapali = j['kapali'] == true;
        _sayfa++;
        _devam = j['devam'] == true;
        _liste.addAll(((j['items'] as List?) ?? const []).whereType<Map>().map(FkGonderi.fromJson).where((g) => g.fotolar.isNotEmpty));
      });
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _avBildir() async {
    await CatchFormScreen.open(context, selectedSpot.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 12,
        title: const Row(children: [
          FishkrokLogo(boy: 30),
          SizedBox(width: 8),
          Flexible(child: FishkrokYazi(boy: 22)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _yukle(bastan: true),
            icon: const Icon(Icons.refresh),
          ),
          // 1.13.0: mesaj kutusu (badilerle yazışma, av paylaşma)
          IconButton(
            tooltip: 'Mesajlarım',
            onPressed: () => BadiKutu.ac(context),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Profilim',
            onPressed: () => ProfilEkrani.ac(context),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'kiyidanPaylasAvBildir',
        backgroundColor: Tide.turuncu,
        foregroundColor: Colors.white,
        onPressed: _avBildir,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Av bildir', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_kapali) return const _Bos('KıyıdanPaylaş şu an kapalı.');
    if (_liste.isEmpty && _yukleniyor) return const Center(child: CircularProgressIndicator(color: fishkrokAcik));
    if (_liste.isEmpty && _hata != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_hata!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
          TextButton(onPressed: () => _yukle(bastan: true), child: const Text('Tekrar dene')),
        ]),
      );
    }
    if (_liste.isEmpty) {
      return _Bos('Henüz paylaşım yok. İlk avını sen bildir; onaylanınca burada herkes görür.',
          dugme: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tide.turuncu), onPressed: _avBildir, child: const AvBildirYazisi(renk: Colors.white)));
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _liste.length,
      onPageChanged: (i) {
        if (i >= _liste.length - 3) _yukle();
      },
      itemBuilder: (_, i) => FkSayfa(g: _liste[i], onDegisti: () => setState(() {})),
    );
  }
}

class _Bos extends StatelessWidget {
  final String yazi;
  final Widget? dugme;
  const _Bos(this.yazi, {this.dugme});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const FishkrokLogo(boy: 64, kanca: Colors.white),
            const SizedBox(height: 6),
            const FishkrokYazi(boy: 30, renk: Colors.white),
            const SizedBox(height: 14),
            Text(yazi, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            if (dugme != null) ...[const SizedBox(height: 16), dugme!],
          ]),
        ),
      );
}

/// Tek paylaşım (tam ekran, Reels gibi): fotoğraflar yana kaydırılır, eylemler sağda
class FkSayfa extends StatefulWidget {
  final FkGonderi g;
  final VoidCallback onDegisti;
  const FkSayfa({super.key, required this.g, required this.onDegisti});

  @override
  State<FkSayfa> createState() => _FkSayfaState();
}

class _FkSayfaState extends State<FkSayfa> {
  int _foto = 0;
  bool _mesgul = false;

  FkGonderi get g => widget.g;

  void _soyle(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _begen() async {
    if (_mesgul || !await Topluluk.uyeHazir(context, 'Beğenmek')) return;
    setState(() {
      _mesgul = true;
      g.begendim = !g.begendim;
      g.begeni += g.begendim ? 1 : -1;
    });
    try {
      final j = await Topluluk.gonder('fk_begen', {'id': g.id});
      g.begendim = j['begendim'] == true;
      g.begeni = tIntN(j['begeni']) ?? g.begeni;
    } catch (e) {
      g.begendim = !g.begendim;
      g.begeni += g.begendim ? 1 : -1;
      if (mounted) _soyle('$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
      widget.onDegisti();
    }
  }

  Future<void> _puanla() async {
    if (!await Topluluk.uyeHazir(context, 'Puan vermek') || !mounted) return;
    final p = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${g.balik} paylaşımına puan ver', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: () => Navigator.of(ctx).pop(i),
                  icon: Icon(i <= g.puanim ? Icons.star : Icons.star_border, color: const Color(0xFFF2A51A)),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (p == null) return;
    try {
      final j = await Topluluk.gonder('fk_puan', {'id': g.id, 'puan': '$p'});
      setState(() {
        g.puanim = p;
        g.puan = tDoubleN(j['puan']) ?? g.puan;
        g.puanSayi = tIntN(j['puan_sayi']) ?? g.puanSayi;
      });
      _soyle('$p yıldız verdin');
    } catch (e) {
      if (mounted) _soyle('$e');
    }
  }

  Future<void> _yorumlar() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FkYorumlar(g: g),
    );
    if (mounted) setState(() {});
  }

  Future<void> _paylas() async {
    String link;
    try {
      link = '${(await Topluluk.al('fk_link', {'id': g.id}))['link']}';
    } catch (e) {
      if (mounted) _soyle('$e');
      return;
    }
    if (!mounted) return;
    final metin = fishkrokPaylasimMetni(g, link);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Paylaş', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _PaylasDugme('Instagram', const Color(0xFFE1306C), Icons.camera_alt_outlined, () async {
                Navigator.of(ctx).pop();
                final aciklama = fishkrokPaylasimMetni(g, '');
                await Clipboard.setData(ClipboardData(text: aciklama));
                _soyle('Açıklama kopyalandı; Instagram\'da yapıştırabilirsin.');
                await _gorsellePaylas(aciklama);
              }),
              _PaylasDugme('WhatsApp', const Color(0xFF25D366), Icons.chat_outlined, () {
                Navigator.of(ctx).pop();
                launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}'), mode: LaunchMode.externalApplication);
              }),
              _PaylasDugme('Telegram', const Color(0xFF229ED9), Icons.send_outlined, () {
                Navigator.of(ctx).pop();
                launchUrl(
                    Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(fishkrokPaylasimMetni(g, ''))}'),
                    mode: LaunchMode.externalApplication);
              }),
              _PaylasDugme('Bağlantıyı\nkopyala', Tide.derin, Icons.link, () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: link));
                _soyle('KıyıdanPaylaş avı bağlantısı kopyalandı.');
              }),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF5F1EA), borderRadius: BorderRadius.circular(10)),
              child: Text('${fishkrokPaylasimMetni(g, '').trim()}\n\n🔗 KıyıdanPaylaş avı',
                  style: const TextStyle(fontSize: 12, height: 1.4)),
            ),
            const SizedBox(height: 6),
            const Text('Bağlantıyı açan kişi KıyıdanAv üyesi değilse paylaşımı göremez; üye olmaya davet edilir.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B6A60))),
          ]),
        ),
      ),
    );
  }

  /// Instagram için ilk fotoğrafı görsel olarak paylaşım menüsüne verir
  Future<void> _gorsellePaylas(String metin) async {
    try {
      final r = await http.get(Uri.parse(g.fotolar.first)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw StateError('foto');
      await Share.shareXFiles([XFile.fromData(r.bodyBytes, mimeType: 'image/jpeg', name: 'fishkrok.jpg')],
          text: metin, sharePositionOrigin: Sharer.origin());
    } catch (_) {
      await Share.share(metin, sharePositionOrigin: Sharer.origin());
    }
  }

  Future<void> _sikayet() async {
    if (!await Topluluk.uyeHazir(context, 'Şikâyet etmek') || !mounted) return;
    final neden = await sikayetNedeniSor(context);
    if (neden == null) return;
    try {
      final j = await Topluluk.gonder('sikayet', {'tur': 'paylasim', 'hedef': g.id, 'neden': neden});
      _soyle('${j['mesaj'] ?? 'Şikâyetin iletildi.'}');
    } catch (e) {
      if (mounted) _soyle('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: g.fotolar.length,
        onPageChanged: (i) => setState(() => _foto = i),
        itemBuilder: (_, i) => FkFoto(url: g.fotolar[i], instagram: g.instagram),
      ),
      // Alt yazı alanı için koyulaştırma
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
              stops: [0, 0.6, 1],
            ),
          ),
        ),
      ),
      if (g.fotolar.length > 1)
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < g.fotolar.length; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == _foto ? Tide.turuncu : Colors.white70),
              ),
          ]),
        ),
      // Sağdaki eylemler
      Positioned(
        right: 8,
        bottom: 110,
        child: Column(children: [
          _Eylem(g.begendim ? Icons.favorite : Icons.favorite_border, '${g.begeni}', _begen,
              renk: g.begendim ? const Color(0xFFE0453A) : Colors.white),
          _Eylem(Icons.mode_comment_outlined, '${g.yorumSayi}', _yorumlar),
          _Eylem(g.puanim > 0 ? Icons.star : Icons.star_border, g.puanSayi == 0 ? 'Puan' : g.puan.toStringAsFixed(1), _puanla,
              renk: g.puanim > 0 ? const Color(0xFFF2A51A) : Colors.white),
          _Eylem(Icons.ios_share, 'Paylaş', _paylas),
          _Eylem(Icons.send_outlined, 'Badiye', () => BadiKutu.avGonder(context, g.id, '${g.balik} · ${g.mera}')),
          _Eylem(Icons.flag_outlined, 'Şikâyet', _sikayet),
        ]),
      ),
      // Alt bilgiler
      Positioned(
        left: 14,
        right: 76,
        bottom: 54,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(url: g.avatar, ad: g.ad, boy: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text(g.kim,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${g.balik}${g.miktar.isNotEmpty ? ' · ${g.miktar}' : ''} — ${g.mera}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          if (g.yem.isNotEmpty) Text('Yem / teknik: ${g.yem}', style: const TextStyle(color: Colors.white, fontSize: 13)),
          if (g.meraBilgi.isNotEmpty) Text('Mera: ${g.meraBilgi}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          if (g.not.isNotEmpty)
            Text(g.not, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        ]),
      ),
    ]);
  }
}

/// Fotoğraf + üzerindeki hesap adları (sol alt: paylaşan, sağ alt: @kiyidabirivar / @kiyidanav)
class FkFoto extends StatelessWidget {
  final String url;
  final String instagram;
  final BoxFit fit;
  const FkFoto({super.key, required this.url, required this.instagram, this.fit = BoxFit.cover});

  static const _golge = [Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.network(url, fit: fit, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0D2A30))),
      if (instagram.isNotEmpty)
        Positioned(
          left: 12,
          bottom: 12,
          child: Text('@$instagram', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, shadows: _golge)),
        ),
      const Positioned(
        right: 12,
        bottom: 12,
        child: Text('@kiyidabirivar\n@kiyidanav',
            textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, height: 1.25, shadows: _golge)),
      ),
    ]);
  }
}

class _Eylem extends StatelessWidget {
  final IconData ikon;
  final String yazi;
  final VoidCallback onTap;
  final Color renk;
  const _Eylem(this.ikon, this.yazi, this.onTap, {this.renk = Colors.white});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkResponse(
          onTap: onTap,
          radius: 30,
          child: Column(children: [
            Icon(ikon, color: renk, size: 32, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
            const SizedBox(height: 2),
            Text(yazi, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
          ]),
        ),
      );
}

class _PaylasDugme extends StatelessWidget {
  final String ad;
  final Color renk;
  final IconData ikon;
  final VoidCallback onTap;
  const _PaylasDugme(this.ad, this.renk, this.ikon, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(14)),
              child: Icon(ikon, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(ad, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Yorumlar (alt sayfa)
class FkYorumlar extends StatefulWidget {
  final FkGonderi g;
  const FkYorumlar({super.key, required this.g});

  @override
  State<FkYorumlar> createState() => _FkYorumlarState();
}

class _FkYorumlarState extends State<FkYorumlar> {
  final _metin = TextEditingController();
  List<FkYorum>? _liste;
  String? _uyari;
  bool _gonderiyor = false;

  @override
  void initState() {
    super.initState();
    Topluluk.al('fk_yorumlar', {'id': widget.g.id}).then((j) {
      if (mounted) setState(() => _liste = ((j['items'] as List?) ?? const []).whereType<Map>().map(FkYorum.fromJson).toList());
    }).catchError((Object e) {
      if (mounted) setState(() => _liste = widget.g.yorumlar);
    });
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final t = _metin.text.trim();
    if (t.length < 2) return;
    final hata = yorumDenetle(t);
    if (hata != null) {
      setState(() => _uyari = '$hata Yorum gönderilmedi.');
      return;
    }
    if (!await Topluluk.uyeHazir(context, 'Yorum yazmak')) return;
    setState(() {
      _gonderiyor = true;
      _uyari = null;
    });
    try {
      final j = await Topluluk.gonder('fk_yorum', {'id': widget.g.id, 'metin': t});
      final y = FkYorum.fromJson(j['yorum'] as Map);
      setState(() {
        _liste = [...?_liste, y];
        widget.g.yorumSayi++;
        _metin.clear();
      });
    } catch (e) {
      setState(() => _uyari = '$e');
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
    }
  }

  Future<void> _sil(FkYorum y) async {
    try {
      await Topluluk.gonder('fk_yorum_sil', {'yorum': '${y.id}'});
      setState(() {
        _liste = _liste?.where((e) => e.id != y.id).toList();
        widget.g.yorumSayi = (widget.g.yorumSayi - 1).clamp(0, 1 << 30).toInt();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(children: [
          Text('Yorumlar (${widget.g.yorumSayi})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Expanded(
            child: l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? const Center(child: Text('İlk yorumu sen yaz.'))
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final y in l)
                          ListTile(
                            dense: true,
                            title: Text(y.ad, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(y.metin),
                            trailing: y.benim
                                ? IconButton(tooltip: 'Sil', onPressed: () => _sil(y), icon: const Icon(Icons.delete_outline))
                                : null,
                          ),
                      ]),
          ),
          if (_uyari != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_uyari!, style: const TextStyle(color: Tide.mercan, fontWeight: FontWeight.w700)),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Telefon numarası, Instagram hesabı ve bağlantı paylaşılamaz.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B6A60))),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _metin,
                    maxLength: 400,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Yorum yaz…', counterText: '', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                  onPressed: _gonderiyor ? null : _gonder,
                  child: const Text('Gönder'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Şikâyet nedeni seçimi (Fishkrok ve Badimi bul ortak)
Future<String?> sikayetNedeniSor(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Neden şikâyet ediyorsun?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          for (final n in const ['Spam / reklam', 'Taciz veya hakaret', 'Sahte hesap', 'Uygunsuz içerik', 'Yasak boy / yasak av', 'Diğer'])
            ListTile(title: Text(n), onTap: () => Navigator.of(ctx).pop(n)),
        ]),
      ),
    );

/// Mera Bilgisi'ndeki Fishkrok girişi
class FishkrokGirisKarti extends StatelessWidget {
  final VoidCallback onTap;
  const FishkrokGirisKarti({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6E2D6))),
              child: const Row(children: [
                FishkrokMarka(boy: 40),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Üyelerin av paylaşımları: beğen, yorum yap, puan ver, paylaş.',
                      style: TextStyle(fontSize: 13.5, height: 1.35)),
                ),
                Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      );
}

