import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'catches.dart';
import 'fishkrok.dart' show sikayetNedeniSor;
import 'harita_secici.dart';
import 'profil.dart';
import 'sea.dart';
import 'sea_card.dart';
import 'theme.dart';
import 'topluluk_api.dart';

/// Badimi bul: gideceğin kıyıyı seç, oradaki KıyıdanAv balıkçılarını gör, takip et, mesajlaş.
/// Konum en fazla ~1 km hassasiyetle ve yalnızca kendin açarsan paylaşılır.
class BadiEkrani extends StatefulWidget {
  const BadiEkrani({super.key});

  static Future<void> ac(BuildContext context) async {
    if (!Api.config.features.badi) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Badimi bul şu an kapalı.')));
      return;
    }
    if (!await Topluluk.uyeHazir(context, 'Badimi bul') || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadiEkrani()));
  }

  @override
  State<BadiEkrani> createState() => _BadiEkraniState();
}

class BadiUye {
  final int id;
  final String ad, avatar, kamis, yer, plan;
  final double km;
  bool takip;
  final bool ben;
  BadiUye.fromJson(Map j)
      : id = tIntN(j['id']) ?? 0,
        ad = '${j['ad'] ?? 'Balıkçı'}',
        avatar = '${j['avatar'] ?? ''}'.startsWith('https://') ? '${j['avatar']}' : '',
        kamis = '${j['kamis'] ?? ''}'.replaceAll(',', ', '),
        yer = '${j['yer'] ?? ''}',
        plan = '${j['plan'] ?? ''}',
        km = tDoubleN(j['km']) ?? 0,
        takip = j['takip'] == true,
        ben = j['ben'] == true;
}

class _BadiEkraniState extends State<BadiEkrani> {
  late LatLng _yer = LatLng(selectedSpot.value.lat, selectedSpot.value.lon);
  late String _yerAdi = selectedSpot.value.name;
  int _r = 25;
  List<BadiUye>? _liste;
  List<Map>? _engelli;
  Map? _benim;
  String? _hata;
  final _plan = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  void _soyle(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final j = await Topluluk.al('badi_yakin', {
        'lat': _yer.latitude.toStringAsFixed(3),
        'lon': _yer.longitude.toStringAsFixed(3),
        'r': '$_r',
      });
      if (!mounted) return;
      setState(() {
        _liste = ((j['items'] as List?) ?? const []).whereType<Map>().map(BadiUye.fromJson).toList();
        _engelli = ((j['engellediklerim'] as List?) ?? const []).whereType<Map>().toList();
        _benim = j['benim'] is Map ? j['benim'] as Map : null;
        if (_plan.text.isEmpty && _benim != null) _plan.text = '${_benim!['plan'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _yerSec() async {
    final s = await Navigator.of(context).push<Spot>(MaterialPageRoute(
        builder: (_) => HaritaSecici(baslik: 'Nereye gideceksin?', baslangic: _yer, secYazisi: 'Burayı ara', liste: false)));
    if (s == null) return;
    setState(() {
      _yer = LatLng(s.lat, s.lon);
      _yerAdi = s.name;
    });
    _yukle();
  }

  Future<void> _gorun() async {
    try {
      final j = await Topluluk.gonder('badi_konum', {
        'lat': _yer.latitude.toStringAsFixed(3),
        'lon': _yer.longitude.toStringAsFixed(3),
        'yer': _yerAdi,
        'plan': _plan.text.trim(),
      });
      _soyle('${j['mesaj'] ?? 'Listede görünüyorsun.'}');
      _yukle();
    } catch (e) {
      _soyle('$e');
    }
  }

  Future<void> _gizlen() async {
    try {
      final j = await Topluluk.gonder('badi_kapat', const {});
      _soyle('${j['mesaj'] ?? 'Listeden çıktın.'}');
      _yukle();
    } catch (e) {
      _soyle('$e');
    }
  }

  Future<void> _takip(BadiUye u) async {
    try {
      final j = await Topluluk.gonder('badi_takip', {'hedef': '${u.id}'});
      setState(() => u.takip = j['aktif'] == true);
    } catch (e) {
      _soyle('$e');
    }
  }

  Future<void> _engelle(int id, String ad) async {
    try {
      final j = await Topluluk.gonder('badi_engel', {'hedef': '$id'});
      _soyle(j['aktif'] == true ? '$ad engellendi: seni göremez, mesaj atamaz.' : 'Engel kaldırıldı.');
      _yukle();
    } catch (e) {
      _soyle('$e');
    }
  }

  Future<void> _sikayet(BadiUye u) async {
    final n = await sikayetNedeniSor(context);
    if (n == null) return;
    try {
      final j = await Topluluk.gonder('sikayet', {'tur': 'uye', 'hedef': '${u.id}', 'neden': n});
      _soyle('${j['mesaj'] ?? 'Şikâyetin iletildi.'}');
    } catch (e) {
      _soyle('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badimi bul'),
        actions: [
          IconButton(
            tooltip: 'Mesajlarım',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadiKutu())),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          const Text('Birlikte ava çıkacak balıkçıları bul: gideceğin kıyıyı seç, orada olan KıyıdanAv üyelerini gör.',
              style: TextStyle(color: Color(0xFF6B6A60))),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE6E2D6))),
              leading: const Icon(Icons.place, color: Tide.turuncu),
              title: Text(_yerAdi, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('$_r km çevresi'),
              trailing: const Text('Haritada seç', style: TextStyle(color: Tide.turuncu, fontWeight: FontWeight.w700)),
              onTap: _yerSec,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final r in const [10, 25, 50, 100])
              ChoiceChip(
                label: Text('$r km'),
                selected: _r == r,
                selectedColor: Tide.somon,
                onSelected: (_) {
                  setState(() => _r = r);
                  _yukle();
                },
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_benim == null ? 'Sen de listede görün' : 'Listede görünüyorsun: ${_benim!['yer'] ?? ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: _plan,
                maxLength: 160,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Planın (ör. Cumartesi 06:00, LRF, 1 kişilik yer var)',
                  hintStyle: TextStyle(color: Color(0x99FFFFFF)),
                  counterStyle: TextStyle(color: Color(0x99FFFFFF)),
                  filled: true,
                  fillColor: Color(0x1FFFFFFF),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  isDense: true,
                ),
              ),
              Row(children: [
                if (_benim != null)
                  TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70), onPressed: _gizlen, child: const Text('Listeden çık')),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                  onPressed: _gorun,
                  child: Text(_benim == null ? 'Beni göster' : 'Güncelle'),
                ),
              ]),
              const Text('Yaklaşık konumun (~1 km) ve planın yalnızca Badimi bul\'u açan üyelere görünür.',
                  style: TextStyle(color: Color(0xFFBFD6D1), fontSize: 11.5)),
            ]),
          ),
          const SizedBox(height: 14),
          if (_hata != null) Text(_hata!, style: const TextStyle(color: Tide.mercan)),
          if (l == null && _hata == null) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          if (l != null && l.where((u) => !u.ben).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Bu çevrede şu an görünen balıkçı yok. Yarıçapı büyüt ya da kendini göster; gelenler seni bulsun.'),
            ),
          for (final u in (l ?? const <BadiUye>[]).where((u) => !u.ben)) _kart(u),
          if ((_engelli ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Engellediklerin', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final e in _engelli!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${e['ad'] ?? 'Balıkçı'}'),
                trailing: TextButton(
                    onPressed: () => _engelle(tIntN(e['id']) ?? 0, '${e['ad']}'), child: const Text('Engeli kaldır')),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _kart(BadiUye u) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE6E2D6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(url: u.avatar, ad: u.ad, boy: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text([if (u.kamis.isNotEmpty) u.kamis, if (u.yer.isNotEmpty) u.yer].join(' · '),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B6A60))),
              ]),
            ),
            Text('${u.km.toStringAsFixed(u.km < 10 ? 1 : 0)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'engel' ? _engelle(u.id, u.ad) : _sikayet(u),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'engel', child: Text('Engelle')),
                PopupMenuItem(value: 'sikayet', child: Text('Şikâyet et')),
              ],
            ),
          ]),
          if (u.plan.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Plan: ${u.plan}')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _takip(u),
                style: OutlinedButton.styleFrom(
                    foregroundColor: u.takip ? Colors.white : Tide.turuncu,
                    backgroundColor: u.takip ? Tide.turuncu : null,
                    side: const BorderSide(color: Tide.turuncu)),
                child: Text(u.takip ? 'Takip ediliyor' : 'Takip et'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tide.derin),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => BadiSohbet(id: u.id, ad: u.ad, avatar: u.avatar))),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Mesaj'),
              ),
            ),
          ]),
        ]),
      );
}

/// Mesaj kutusu
class BadiKutu extends StatefulWidget {
  const BadiKutu({super.key});

  /// Üyelik denetimiyle açar (KıyıdanPaylaş, Hesabım, bildirim)
  static Future<void> ac(BuildContext context) async {
    if (!await Topluluk.uyeHazir(context, 'Mesajlaşmak') || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadiKutu()));
  }

  /// 1.13.0: KıyıdanPaylaş'taki bir avı badiye mesajla gönderir
  static Future<void> avGonder(BuildContext context, String avId, String baslik) async {
    if (!await Topluluk.uyeHazir(context, 'Av paylaşmak') || !context.mounted) return;
    final b = await Navigator.of(context).push<BadiSecim>(
        MaterialPageRoute(builder: (_) => BadiSec(baslik: 'Avı kime gönderelim?', alt: baslik)));
    if (b == null || !context.mounted) return;
    try {
      await Topluluk.gonder('badi_mesaj', {'alici': '${b.id}', 'av': avId, 'metin': ''});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Av ${b.ad} adlı badine gönderildi.')));
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BadiSohbet(id: b.id, ad: b.ad, avatar: b.avatar)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  State<BadiKutu> createState() => _BadiKutuState();
}

class _BadiKutuState extends State<BadiKutu> {
  late Future<Map<String, dynamic>> _f = Topluluk.al('badi_kutu');

  void _yenile() => setState(() => _f = Topluluk.al('badi_kutu'));

  Future<void> _yeni() async {
    final b = await Navigator.of(context)
        .push<BadiSecim>(MaterialPageRoute(builder: (_) => const BadiSec(baslik: 'Yeni mesaj')));
    if (b == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BadiSohbet(id: b.id, ad: b.ad, avatar: b.avatar)));
    if (mounted) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlarım'),
        actions: [IconButton(tooltip: 'Yenile', onPressed: _yenile, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'badiYeniMesaj',
        backgroundColor: Tide.turuncu,
        foregroundColor: Colors.white,
        onPressed: _yeni,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Yeni mesaj', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}', textAlign: TextAlign.center)),
                TextButton(onPressed: _yenile, child: const Text('Tekrar dene')),
              ]),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = ((snap.data!['items'] as List?) ?? const []).whereType<Map>().toList();
          if (l.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Henüz mesajın yok.\n"Yeni mesaj" ile takip ettiğin badilere yazabilir, '
                    'KıyıdanPaylaş\'taki avları "Badiye" düğmesiyle gönderebilirsin.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _yenile(),
            child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
              for (final m in l)
                ListTile(
                  leading: Avatar(url: '${m['avatar'] ?? ''}', ad: '${m['ad'] ?? ''}'),
                  title: Text('${m['ad']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${m['son'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: (tInt(m['okunmamis'])) > 0
                      ? CircleAvatar(radius: 11, backgroundColor: Tide.turuncu, child: Text('${m['okunmamis']}', style: const TextStyle(color: Colors.white, fontSize: 11)))
                      : null,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BadiSohbet(id: tInt(m['id']), ad: '${m['ad']}', avatar: '${m['avatar'] ?? ''}')));
                    if (mounted) _yenile();
                  },
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Seçilen badi
class BadiSecim {
  final int id;
  final String ad, avatar;
  const BadiSecim(this.id, this.ad, this.avatar);
}

/// Mesaj atılabilecek badiler: takip ettiklerin, seni takip edenler ve yazıştıkların
class BadiSec extends StatefulWidget {
  final String baslik;
  final String alt;
  const BadiSec({super.key, required this.baslik, this.alt = ''});

  @override
  State<BadiSec> createState() => _BadiSecState();
}

class _BadiSecState extends State<BadiSec> {
  late final Future<Map<String, dynamic>> _f = Topluluk.al('badi_listem');
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('${snap.error}')));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final hepsi = ((snap.data!['items'] as List?) ?? const []).whereType<Map>().toList();
          final l = _ara.isEmpty
              ? hepsi
              : hepsi.where((m) => '${m['ad']}'.toLowerCase().contains(_ara.toLowerCase())).toList();
          return ListView(children: [
            if (widget.alt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(widget.alt, style: const TextStyle(fontWeight: FontWeight.w700, color: Tide.derin)),
              ),
            if (hepsi.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'Badi ara', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _ara = v.trim()),
                ),
              ),
            if (hepsi.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('Henüz badin yok. Badimi bul\'dan yakınındaki balıkçıları takip et; '
                      'takip ettiklerine buradan mesaj atabilirsin.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (Api.config.features.badi)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Tide.derin),
                      onPressed: () => BadiEkrani.ac(context),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Badimi bul'),
                    ),
                ]),
              ),
            for (final m in l)
              ListTile(
                leading: Avatar(url: '${m['avatar'] ?? ''}', ad: '${m['ad'] ?? ''}'),
                title: Text('${m['ad']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(m['takip'] == true
                    ? (m['takipci'] == true ? 'Karşılıklı takip' : 'Takip ediyorsun')
                    : (m['takipci'] == true ? 'Seni takip ediyor' : 'Yazıştığın balıkçı')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(BadiSecim(tInt(m['id']), '${m['ad']}', '${m['avatar'] ?? ''}')),
              ),
          ]);
        },
      ),
    );
  }
}

/// Profilim › Takip ettiklerim / Beni takip edenler. Takipçini geri takip edebilir, mesaj atabilirsin.
class TakipEkrani extends StatefulWidget {
  /// 0: takip ettiklerim, 1: beni takip edenler
  final int sekme;
  const TakipEkrani({super.key, this.sekme = 0});

  static Future<void> ac(BuildContext context, {int sekme = 0}) async {
    if (!await Topluluk.uyeHazir(context, 'Takip listesi') || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TakipEkrani(sekme: sekme)));
  }

  @override
  State<TakipEkrani> createState() => _TakipEkraniState();
}

class _TakipEkraniState extends State<TakipEkrani> {
  List<Map>? _takip, _takipci;
  String? _hata;
  final Set<int> _isleniyor = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final j = await Topluluk.al('badi_takiplerim');
      if (!mounted) return;
      setState(() {
        _hata = null;
        _takip = ((j['takip'] as List?) ?? const []).whereType<Map>().map((e) => Map.of(e)).toList();
        _takipci = ((j['takipci'] as List?) ?? const []).whereType<Map>().map((e) => Map.of(e)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _degistir(Map u) async {
    final id = tInt(u['id']);
    setState(() => _isleniyor.add(id));
    try {
      final j = await Topluluk.gonder('badi_takip', {'hedef': '$id'});
      final aktif = j['aktif'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(aktif ? '${u['ad']} adlı balıkçıyı takip ediyorsun.' : '${u['ad']} takipten çıkarıldı.')));
      await _yukle();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isleniyor.remove(id));
    }
  }

  Widget _liste(List<Map>? l, bool takipcilerim) {
    if (l == null) {
      return Center(child: _hata != null ? Padding(padding: const EdgeInsets.all(20), child: Text(_hata!, textAlign: TextAlign.center)) : const CircularProgressIndicator());
    }
    if (l.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            Icon(takipcilerim ? Icons.person_add_alt : Icons.group_outlined, size: 48, color: Tide.derin),
            const SizedBox(height: 10),
            Text(
                takipcilerim
                    ? 'Henüz seni takip eden yok. Biri seni takip ettiğinde bildirim alırsın ve burada görünür.'
                    : 'Henüz kimseyi takip etmiyorsun. Badimi bul\'dan yakınındaki balıkçıları bulup takip edebilirsin.',
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (!takipcilerim && Api.config.features.badi)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tide.derin),
                onPressed: () => BadiEkrani.ac(context),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Badimi bul'),
              ),
          ]),
        ),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: l.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final u = l[i];
        final takip = u['takip'] == true;
        final takipci = u['takipci'] == true;
        final id = tInt(u['id']);
        final alt = [
          if (takip && takipci) 'Karşılıklı takip' else if (takipci) 'Seni takip ediyor' else 'Takip ediyorsun',
          if ('${u['il'] ?? ''}'.isNotEmpty) '${u['il']}',
          if ('${u['kamis'] ?? ''}'.isNotEmpty) '${u['kamis']}',
        ].join(' · ');
        return ListTile(
          leading: Avatar(url: '${u['avatar'] ?? ''}', ad: '${u['ad'] ?? ''}'),
          title: Text('${u['ad']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => BadiSohbet(id: id, ad: '${u['ad']}', avatar: '${u['avatar'] ?? ''}'))),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Mesaj gönder',
              icon: const Icon(Icons.chat_bubble_outline, color: Tide.derin),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => BadiSohbet(id: id, ad: '${u['ad']}', avatar: '${u['avatar'] ?? ''}'))),
            ),
            SizedBox(
              width: 112,
              child: _isleniyor.contains(id)
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : takip
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: Tide.kaya),
                          onPressed: () => _degistir(u),
                          child: const Text('Takiptesin', style: TextStyle(fontSize: 12.5)))
                      : FilledButton(
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), backgroundColor: Tide.turuncu),
                          onPressed: () => _degistir(u),
                          child: Text(takipci ? 'Geri takip et' : 'Takip et', style: const TextStyle(fontSize: 12.5))),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.sekme.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Takip'),
          bottom: TabBar(
            labelColor: Tide.turuncu,
            indicatorColor: Tide.turuncu,
            tabs: [
              Tab(text: 'Takip ettiklerim${_takip == null ? '' : ' (${_takip!.length})'}'),
              Tab(text: 'Beni takip edenler${_takipci == null ? '' : ' (${_takipci!.length})'}'),
            ],
          ),
        ),
        body: TabBarView(children: [
          RefreshIndicator(onRefresh: _yukle, child: _liste(_takip, false)),
          RefreshIndicator(onRefresh: _yukle, child: _liste(_takipci, true)),
        ]),
      ),
    );
  }
}

/// İki üye arasındaki mesajlar. Telefon numarası içeren mesaj yönetici onayına düşer.
class BadiSohbet extends StatefulWidget {
  final int id;
  final String ad;
  final String avatar;
  const BadiSohbet({super.key, required this.id, required this.ad, this.avatar = ''});

  @override
  State<BadiSohbet> createState() => _BadiSohbetState();
}

class _BadiSohbetState extends State<BadiSohbet> {
  final _metin = TextEditingController();
  final _kaydir = ScrollController();
  List<Map>? _liste;
  bool _engelli = false;
  bool _gonderiyor = false;
  /// Fotoğraf eklerini açmak için üyelik anahtarı (yalnızca gönderen ve alıcı görebilir)
  String? _anahtar;

  @override
  void initState() {
    super.initState();
    _yukle();
    CatchService.token().then((t) {
      if (mounted) setState(() => _anahtar = t);
    });
  }

  @override
  void dispose() {
    _metin.dispose();
    _kaydir.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final j = await Topluluk.al('badi_mesajlar', {'ile': '${widget.id}'});
      if (!mounted) return;
      setState(() {
        _liste = ((j['items'] as List?) ?? const []).whereType<Map>().toList();
        _engelli = j['engelledim'] == true || j['engellendim'] == true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_kaydir.hasClients) _kaydir.jumpTo(_kaydir.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _soyle(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _gonder({String? dosya, LatLng? konum}) async {
    final t = _metin.text.trim();
    if (t.isEmpty && dosya == null && konum == null) return;
    final neden = mesajDenetle(t);
    if (neden != null) {
      _soyle(neden);
      return;
    }
    setState(() => _gonderiyor = true);
    try {
      final j = await Topluluk.gonder(
          'badi_mesaj',
          {
            'alici': '${widget.id}',
            'metin': t,
            if (konum != null) 'lat': konum.latitude.toStringAsFixed(5),
            if (konum != null) 'lon': konum.longitude.toStringAsFixed(5),
          },
          dosya: dosya);
      _metin.clear();
      final m = '${j['mesaj'] ?? ''}';
      if (m.isNotEmpty && mounted) _soyle(m);
      await _yukle();
    } catch (e) {
      if (mounted) _soyle('$e');
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
    }
  }

  /// Ek menüsü: fotoğraf çek, galeriden fotoğraf, bulunduğum konum, haritadan konum
  Future<void> _ekle() async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Fotoğraf çek'), onTap: () => Navigator.pop(c, 'kamera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeriden fotoğraf'), onTap: () => Navigator.pop(c, 'galeri')),
          ListTile(leading: const Icon(Icons.my_location), title: const Text('Bulunduğum konumu gönder'), onTap: () => Navigator.pop(c, 'konum')),
          ListTile(leading: const Icon(Icons.map_outlined), title: const Text('Haritadan konum seç'), onTap: () => Navigator.pop(c, 'harita')),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Mesajlarda telefon numarası, internet bağlantısı, Instagram ve YouTube hesabı paylaşılamaz.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6A60))),
          ),
        ]),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'kamera' || secim == 'galeri') {
      final x = await ImagePicker().pickImage(
          source: secim == 'kamera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x != null) await _gonder(dosya: x.path);
    } else if (secim == 'konum') {
      final k = await _bulunduguKonum();
      if (k != null) await _gonder(konum: k);
    } else {
      final s = await Navigator.of(context).push<Spot>(MaterialPageRoute(
          builder: (_) => HaritaSecici(
              baslik: 'Konum gönder',
              baslangic: LatLng(selectedSpot.value.lat, selectedSpot.value.lon),
              secYazisi: 'Bu konumu gönder',
              liste: false)));
      if (s != null) await _gonder(konum: LatLng(s.lat, s.lon));
    }
  }

  Future<LatLng?> _bulunduguKonum() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _soyle('Telefonun konum servisi kapalı.');
        return null;
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        _soyle('Konum izni verilmedi. Haritadan konum seçebilirsin.');
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      if (mounted) _soyle('Konum alınamadı. Haritadan konum seçebilirsin.');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Avatar(url: widget.avatar, ad: widget.ad, boy: 32),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.ad, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Expanded(
          child: l == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(controller: _kaydir, padding: const EdgeInsets.all(12), children: [
                  if (l.isEmpty) const Center(child: Text('İlk mesajı sen yaz.')),
                  for (final m in l) _balon(m),
                ]),
        ),
        if (_engelli)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Bu üyeyle aranızda engel var; mesaj gönderilemez.', style: TextStyle(color: Tide.mercan)),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(children: [
                IconButton(
                  tooltip: 'Fotoğraf veya konum ekle',
                  onPressed: _gonderiyor ? null : _ekle,
                  icon: const Icon(Icons.add_circle_outline, color: Tide.derin),
                ),
                Expanded(
                  child: TextField(
                    controller: _metin,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 600,
                    decoration: const InputDecoration(
                        hintText: 'Mesaj yaz…', counterText: '', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Tide.turuncu),
                  onPressed: _gonderiyor ? null : () => _gonder(),
                  icon: _gonderiyor
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _balon(Map m) {
    final ben = m['benim'] == true;
    final durum = '${m['durum'] ?? ''}';
    final bekliyor = durum == 'onay_bekliyor';
    final red = durum == 'reddedildi' || durum == 'gizlendi';
    final foto = '${m['foto'] ?? ''}';
    final konum = m['konum'] is Map ? m['konum'] as Map : null;
    return Align(
      alignment: ben ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bekliyor || red ? const Color(0xFFFFF4E8) : (ben ? Tide.turuncu : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: bekliyor || red ? Border.all(color: const Color(0xFFF0A46C)) : (ben ? null : Border.all(color: const Color(0xFFE6E2D6))),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m['av'] is Map) _avKarti(m['av'] as Map, ben),
          if (foto.startsWith('https://')) _fotoEki(foto),
          if (konum != null) _konumEki(LatLng(tDouble(konum['lat']), tDouble(konum['lon'])), ben),
          if (!((foto.isNotEmpty && m['metin'] == '📷 Fotoğraf') || (konum != null && m['metin'] == '📍 Konum')))
            Text('${m['metin'] ?? ''}', style: TextStyle(color: bekliyor || red ? const Color(0xFF8A4A12) : (ben ? Colors.white : Tide.kaya))),
          if (bekliyor)
            const Text('Yönetici onayı bekliyor', style: TextStyle(fontSize: 10.5, color: Color(0xFF8A4A12))),
          if (red)
            Text(durum == 'gizlendi' ? 'Yönetici tarafından kaldırıldı' : 'Yönetici onaylamadı; karşı tarafa iletilmedi',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A4A12))),
        ]),
      ),
    );
  }

  Widget _fotoEki(String url) {
    final b = {if (_anahtar != null) 'X-Av-Anahtar': _anahtar!};
    if (_anahtar == null) return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FotoTam(url: url, baslik: b))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(url,
              headers: b,
              fit: BoxFit.cover,
              loadingBuilder: (c, w, p) =>
                  p == null ? w : const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(12), child: Text('Fotoğraf açılamadı'))),
        ),
      ),
    );
  }

  Widget _konumEki(LatLng k, bool ben) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KonumHaritasi(konum: k, ad: widget.ad))),
        child: Container(
          width: 230,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: ben ? const Color(0x26FFFFFF) : const Color(0xFFF4F2EA), borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 120,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: k, initialZoom: 14),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.kiyidanav.kiyidanav'),
                    MarkerLayer(markers: [
                      Marker(point: k, width: 34, height: 34, child: const Icon(Icons.location_on, color: Tide.mercan, size: 34)),
                    ]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('📍 Konum · haritada aç',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ben ? Colors.white : Tide.kaya)),
            ),
          ]),
        ),
      );
}

/// Mesajdaki fotoğrafın tam ekranı (yakınlaştırılabilir)
class _FotoTam extends StatelessWidget {
  final String url;
  final Map<String, String> baslik;
  const _FotoTam({required this.url, required this.baslik});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(maxScale: 5, child: Image.network(url, headers: baslik))),
      );
}

/// Mesajla gönderilen konum: harita + yol tarifi
class KonumHaritasi extends StatelessWidget {
  final LatLng konum;
  final String ad;
  const KonumHaritasi({super.key, required this.konum, this.ad = ''});

  @override
  Widget build(BuildContext context) {
    final yazi = '${konum.latitude.toStringAsFixed(5)}, ${konum.longitude.toStringAsFixed(5)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Gönderilen konum')),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(initialCenter: konum, initialZoom: 15),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.kiyidanav.kiyidanav'),
            MarkerLayer(markers: [
              Marker(point: konum, width: 46, height: 46, alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on, color: Tide.mercan, size: 46)),
            ]),
            const RichAttributionWidget(showFlutterMapAttribution: false, attributions: [TextSourceAttribution('OpenStreetMap')]),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size.fromHeight(50)),
              onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${konum.latitude},${konum.longitude}'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.directions),
              label: Text('Yol tarifi ($yazi)', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Mesaj kuralı (sunucuyla aynı): telefon, link, Instagram ve YouTube paylaşılamaz. Uygunsa null.
String? mesajDenetle(String s) {
  if (s.isEmpty) return null;
  final sade = s.replaceAll(RegExp(r'[\s().\-/]'), '');
  // Cep (5xx…), sabit hat (0212…) ve uluslararası (+…) numaralar; tarih / saat yazımı takılmaz
  if (RegExp(r'(\+?90|0)?5\d{9}|0[2-4]\d{9}|(\+|00)\d{10,}').hasMatch(sade)) {
    return 'Mesajda telefon numarası paylaşılamaz.';
  }
  final k = s.toLowerCase();
  if (RegExp(r'youtu\.?be|y[o0]u\s*tube|\byt\s*[:=]').hasMatch(k)) return 'Mesajda YouTube kanalı veya bağlantısı paylaşılamaz.';
  if (RegExp(r'(^|[\s(])@[\w.]{2,}|ins?ta\s*gr?am|\binsta\b|\big\s*[:=]', unicode: true).hasMatch(k)) {
    return 'Mesajda Instagram hesabı paylaşılamaz.';
  }
  if (RegExp(r'https?://|www\.|\b[\w-]+\.(com|net|org|tr|me|ly|io|app|link|co|info|xyz|shop|tv|gl|gg|to|page|site)\b', unicode: true)
      .hasMatch(k)) {
    return 'Mesajda internet bağlantısı (link) paylaşılamaz.';
  }
  return null;
}

/// Mesajla paylaşılan av (KıyıdanPaylaş): fotoğraf + balık + mera
Widget _avKarti(Map av, bool ben) {
  final foto = '${av['foto'] ?? ''}';
  final renk = ben ? Colors.white : Tide.kaya;
  return Container(
    width: 220,
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: ben ? const Color(0x26FFFFFF) : const Color(0xFFF4F2EA),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (foto.startsWith('https://'))
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(foto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🎣 ${av['balik'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w800, color: renk)),
          Text('${av['mera'] ?? ''}${'${av['kim'] ?? ''}'.isNotEmpty ? ' · ${av['kim']}' : ''}',
              style: TextStyle(fontSize: 12, color: renk)),
        ]),
      ),
    ]),
  );
}

/// Mera Bilgisi'ndeki Badimi bul girişi
class BadiGirisKarti extends StatelessWidget {
  const BadiGirisKarti({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Material(
          color: Tide.derin,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => BadiEkrani.ac(context),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(backgroundColor: Tide.turuncu, child: Icon(Icons.groups_outlined, color: Colors.white)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Badimi bul', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Gideceğin kıyıdaki balıkçıları bul, takip et, mesajlaş.',
                        style: TextStyle(color: Color(0xFFBFD6D1), fontSize: 12.5)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      );
}
