import 'package:flutter/material.dart';

import 'app_state.dart';
import 'fishkrok.dart';
import 'profil.dart';
import 'theme.dart';
import 'topluluk_api.dart';

/// 1.17.3: KıyıdanPaylaş etkileşim bildirimleri.
/// Üyenin paylaştığı ava gelen beğeni ve yorumlar sunucuda kaydedilir (mobil-topluluk.php?a=fk_bildirimler),
/// telefona anlık bildirim düşer (tür "etkilesim") ve KıyıdanPaylaş'ın üstündeki 🔔 zilinde listelenir.
/// Paylaşımın sahibi, avını kimlerin beğendiğini de görür (a=fk_begenenler).

class FkEtkilesim {
  final int id;
  final String tur; // begeni | yorum
  final String avId, ad, instagram, avatar, balik, mera, metin, zaman;
  final bool okundu;

  FkEtkilesim.fromJson(Map j)
      : id = tInt(j['id']),
        tur = '${j['tur'] ?? ''}',
        avId = '${j['av_id'] ?? ''}',
        ad = '${j['ad'] ?? ''}',
        instagram = '${j['instagram'] ?? ''}',
        avatar = '${j['avatar'] ?? ''}'.startsWith('https://') ? '${j['avatar']}' : '',
        balik = '${j['balik'] ?? ''}',
        mera = '${j['mera'] ?? ''}',
        metin = '${j['metin'] ?? ''}',
        zaman = '${j['zaman'] ?? ''}',
        okundu = j['okundu'] == true;

  String get kim => instagram.isNotEmpty ? '@$instagram' : (ad.isEmpty ? 'Bir balıkçı' : ad);

  String get baslik {
    final av = balik.isEmpty ? 'avını' : '$balik avını';
    return tur == 'yorum' ? '$kim $av yorumladı' : '$kim $av beğendi';
  }
}

class FkBegenen {
  final String ad, instagram, avatar, zaman;
  FkBegenen.fromJson(Map j)
      : ad = '${j['ad'] ?? ''}',
        instagram = '${j['instagram'] ?? ''}',
        avatar = '${j['avatar'] ?? ''}'.startsWith('https://') ? '${j['avatar']}' : '',
        zaman = '${j['zaman'] ?? ''}';
  String get kim => instagram.isNotEmpty ? '@$instagram' : (ad.isEmpty ? 'Balıkçı' : ad);
}

class FkBildirim {
  /// Okunmamış etkileşim sayısı (zil üzerindeki rozet)
  static final okunmamis = ValueNotifier<int>(0);

  static DateTime? _son;

  /// Rozeti sunucudan yeniler (üye değilse 0). [zorla] olmadan en fazla dakikada bir istek.
  static Future<void> yenile({bool zorla = false}) async {
    if (!appState.isMember) {
      okunmamis.value = 0;
      return;
    }
    final simdi = DateTime.now();
    if (!zorla && _son != null && simdi.difference(_son!) < const Duration(minutes: 1)) return;
    _son = simdi;
    try {
      final j = await Topluluk.al('fk_bildirimler', {'say': '1'});
      okunmamis.value = tInt(j['okunmamis']);
    } catch (_) {}
  }

  static Future<void> ac(BuildContext context) async {
    if (!await Topluluk.uyeHazir(context, 'Bildirimlerini görmek') || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FkBildirimEkrani()));
  }

  /// Paylaşımı kimlerin beğendiği (yalnız paylaşımın sahibine; sunucu da denetler)
  static Future<void> begenenler(BuildContext context, FkGonderi g) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _BegenenlerSayfasi(g: g),
      );
}

/// Üst çubuktaki zil (okunmamış sayısıyla)
class FkZil extends StatelessWidget {
  final Color renk;
  const FkZil({super.key, this.renk = Colors.black87});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: FkBildirim.okunmamis,
        builder: (_, n, __) => IconButton(
          tooltip: 'Bildirimler',
          onPressed: () => FkBildirim.ac(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 99 ? '99+' : '$n'),
            backgroundColor: const Color(0xFFE0453A),
            child: Icon(n > 0 ? Icons.notifications_active : Icons.notifications_none, color: renk),
          ),
        ),
      );
}

class FkBildirimEkrani extends StatefulWidget {
  const FkBildirimEkrani({super.key});

  @override
  State<FkBildirimEkrani> createState() => _FkBildirimEkraniState();
}

class _FkBildirimEkraniState extends State<FkBildirimEkrani> {
  List<FkEtkilesim>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // okundu=1: liste açılınca hepsi okundu sayılır (rozet sıfırlanır)
      final j = await Topluluk.al('fk_bildirimler', {'okundu': '1'});
      if (!mounted) return;
      setState(() => _liste = ((j['items'] as List?) ?? const []).whereType<Map>().map(FkEtkilesim.fromJson).toList());
      FkBildirim.okunmamis.value = 0;
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _ac(FkEtkilesim e) async {
    if (e.avId.isEmpty) return;
    try {
      final j = await Topluluk.al('fk_gonderi', {'id': e.avId});
      final g = FkGonderi.fromJson(j['item'] as Map);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FkTekGonderi(g: g, yorumlariAc: e.tur == 'yorum')));
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? ListView(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text(_hata!, textAlign: TextAlign.center)),
                Center(child: TextButton(onPressed: _yukle, child: const Text('Tekrar dene'))),
              ])
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Henüz bildirim yok. Avını paylaştığında beğeni ve yorumlar burada görünür.',
                              textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B6A60))),
                        ),
                      ])
                    : ListView.separated(
                        itemCount: l.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final e = l[i];
                          return ListTile(
                            tileColor: e.okundu ? null : const Color(0xFFFFF4EC),
                            leading: Stack(clipBehavior: Clip.none, children: [
                              Avatar(url: e.avatar, ad: e.ad, boy: 44),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.white,
                                  child: Icon(e.tur == 'yorum' ? Icons.mode_comment : Icons.favorite,
                                      size: 14, color: e.tur == 'yorum' ? Tide.derin : const Color(0xFFE0453A)),
                                ),
                              ),
                            ]),
                            title: Text(e.baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                [if (e.tur == 'yorum' && e.metin.isNotEmpty) '"${e.metin}"', if (e.mera.isNotEmpty) e.mera, e.zaman]
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _ac(e),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Bildirimden açılan tek paylaşım (akıştaki sayfanın aynısı)
class FkTekGonderi extends StatefulWidget {
  final FkGonderi g;
  final bool yorumlariAc;
  const FkTekGonderi({super.key, required this.g, this.yorumlariAc = false});

  @override
  State<FkTekGonderi> createState() => _FkTekGonderiState();
}

class _FkTekGonderiState extends State<FkTekGonderi> {
  @override
  void initState() {
    super.initState();
    if (widget.yorumlariAc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
            context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => FkYorumlar(g: widget.g));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const FishkrokYazi(boy: 20)),
        body: FkSayfa(g: widget.g, onDegisti: () => setState(() {})),
      );
}

class _BegenenlerSayfasi extends StatefulWidget {
  final FkGonderi g;
  const _BegenenlerSayfasi({required this.g});

  @override
  State<_BegenenlerSayfasi> createState() => _BegenenlerSayfasiState();
}

class _BegenenlerSayfasiState extends State<_BegenenlerSayfasi> {
  List<FkBegenen>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    Topluluk.al('fk_begenenler', {'id': widget.g.id}).then((j) {
      if (mounted) setState(() => _liste = ((j['items'] as List?) ?? const []).whereType<Map>().map(FkBegenen.fromJson).toList());
    }).catchError((Object e) {
      if (mounted) setState(() => _hata = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(children: [
        Text('Beğenenler (${l?.length ?? widget.g.begeni})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Expanded(
          child: _hata != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_hata!, textAlign: TextAlign.center)))
              : l == null
                  ? const Center(child: CircularProgressIndicator())
                  : l.isEmpty
                      ? const Center(child: Text('Henüz beğenen yok.'))
                      : ListView(padding: const EdgeInsets.all(8), children: [
                          for (final b in l)
                            ListTile(
                              leading: Avatar(url: b.avatar, ad: b.ad, boy: 40),
                              title: Text(b.kim, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: b.zaman.isEmpty ? null : Text(b.zaman),
                              trailing: const Icon(Icons.favorite, color: Color(0xFFE0453A), size: 18),
                            ),
                        ]),
        ),
      ]),
    );
  }
}
