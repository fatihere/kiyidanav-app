import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';
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
      : id = (j['id'] as num?)?.toInt() ?? 0,
        ad = '${j['ad'] ?? 'Balıkçı'}',
        avatar = '${j['avatar'] ?? ''}'.startsWith('https://') ? '${j['avatar']}' : '',
        kamis = '${j['kamis'] ?? ''}'.replaceAll(',', ', '),
        yer = '${j['yer'] ?? ''}',
        plan = '${j['plan'] ?? ''}',
        km = (j['km'] as num?)?.toDouble() ?? 0,
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
                    onPressed: () => _engelle((e['id'] as num?)?.toInt() ?? 0, '${e['ad']}'), child: const Text('Engeli kaldır')),
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

  @override
  State<BadiKutu> createState() => _BadiKutuState();
}

class _BadiKutuState extends State<BadiKutu> {
  late Future<Map<String, dynamic>> _f = Topluluk.al('badi_kutu');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesajlarım')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = ((snap.data!['items'] as List?) ?? const []).whereType<Map>().toList();
          if (l.isEmpty) return const Center(child: Text('Henüz mesajın yok.'));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _f = Topluluk.al('badi_kutu')),
            child: ListView(children: [
              for (final m in l)
                ListTile(
                  leading: Avatar(url: '${m['avatar'] ?? ''}', ad: '${m['ad'] ?? ''}'),
                  title: Text('${m['ad']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${m['son'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: (m['okunmamis'] as num? ?? 0) > 0
                      ? CircleAvatar(radius: 11, backgroundColor: Tide.turuncu, child: Text('${m['okunmamis']}', style: const TextStyle(color: Colors.white, fontSize: 11)))
                      : null,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BadiSohbet(id: (m['id'] as num).toInt(), ad: '${m['ad']}', avatar: '${m['avatar'] ?? ''}')));
                    if (mounted) setState(() => _f = Topluluk.al('badi_kutu'));
                  },
                ),
            ]),
          );
        },
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

  @override
  void initState() {
    super.initState();
    _yukle();
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

  Future<void> _gonder() async {
    final t = _metin.text.trim();
    if (t.isEmpty) return;
    setState(() => _gonderiyor = true);
    try {
      final j = await Topluluk.gonder('badi_mesaj', {'alici': '${widget.id}', 'metin': t});
      _metin.clear();
      final m = '${j['mesaj'] ?? ''}';
      if (m.isNotEmpty && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      await _yukle();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
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
                  onPressed: _gonderiyor ? null : _gonder,
                  icon: const Icon(Icons.send),
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
    final red = durum == 'reddedildi';
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
          Text('${m['metin'] ?? ''}', style: TextStyle(color: bekliyor || red ? const Color(0xFF8A4A12) : (ben ? Colors.white : Tide.kaya))),
          if (bekliyor)
            const Text('Telefon numarası içeriyor · yönetici onayı bekliyor', style: TextStyle(fontSize: 10.5, color: Color(0xFF8A4A12))),
          if (red) const Text('Yönetici onaylamadı; karşı tarafa iletilmedi', style: TextStyle(fontSize: 10.5, color: Color(0xFF8A4A12))),
        ]),
      ),
    );
  }
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
