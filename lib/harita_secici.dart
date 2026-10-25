import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'app_state.dart';
import 'locate.dart';
import 'mera.dart';
import 'meralarim.dart';
import 'sea.dart';
import 'sea_card.dart';
import 'theme.dart';

/// Harita katmanları: uydu (Esri World Imagery + yer adları) ve sokak haritası (OpenStreetMap)
enum HaritaKatman { uydu, harita }

const _uyduUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const _etiketUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Haritadan mera seçimi: harita kaydırılır, ortadaki iğnenin altındaki kıyı seçilir.
/// İğne kayıtlı bir meraya 2 km'den yakınsa o mera seçilir. Değilse (1.13.2) iğnenin altındaki yerin
/// gerçek adı öğrenilir (ör. "Anadolu Kavağı"), yeni mera olarak Meralarım'a eklenir ve haritada işaretlenir;
/// hava ve deniz tahmini iğnenin kendi noktasından alınır.
Future<Spot?> haritadanSec(BuildContext context, {String baslik = 'Haritadan mera seç', bool kaydet = true}) async {
  final s = await Navigator.of(context).push<Spot>(MaterialPageRoute(builder: (_) => HaritaSecici(baslik: baslik, liste: kaydet)));
  if (s != null && s.name == _listeIstegi && context.mounted) {
    await showSpotPicker(context, listeOnly: true);
    return null;
  }
  if (s != null && kaydet) await Locate.manualPick(s);
  return s;
}

const _listeIstegi = '__liste__';

class HaritaSecici extends StatefulWidget {
  final String baslik;
  final LatLng? baslangic;
  final String secYazisi;
  /// "Listeden seç" düğmesi gösterilsin mi (Mera Bilgisi'nde evet, Badimi bul'da hayır)
  final bool liste;
  const HaritaSecici(
      {super.key, this.baslik = 'Haritadan mera seç', this.baslangic, this.secYazisi = 'Bu noktayı seç', this.liste = true});

  @override
  State<HaritaSecici> createState() => _HaritaSeciciState();
}

class _HaritaSeciciState extends State<HaritaSecici> {
  final _ctrl = MapController();
  late LatLng _merkez = widget.baslangic ?? LatLng(selectedSpot.value.lat, selectedSpot.value.lon);
  HaritaKatman _katman = HaritaKatman.uydu;
  bool _konumAraniyor = false;

  (Spot, double) get _yakin => Locate.nearest(_merkez.latitude, _merkez.longitude);

  // 1.13.2: iğnenin altındaki yerin öğrenilen adı
  String? _yerAdi;
  Side? _yerYaka;
  LatLng? _adNokta;
  bool _adAraniyor = false;
  Timer? _adZaman;

  bool get _ogren => widget.liste;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _adBulZamanla());
  }

  @override
  void dispose() {
    _adZaman?.cancel();
    super.dispose();
  }

  bool get _adGuncel => _adNokta != null && Locate.km(_adNokta!.latitude, _adNokta!.longitude, _merkez.latitude, _merkez.longitude) < 0.3;

  void _adBulZamanla() {
    _adZaman?.cancel();
    if (!_ogren || _yakin.$2 < 2 || _yakin.$2 > 40) return;
    _adZaman = Timer(const Duration(milliseconds: 800), _adBul);
  }

  Future<void> _adBul() async {
    if (_adGuncel || !mounted) return;
    final nokta = _merkez;
    setState(() => _adAraniyor = true);
    final r = await Meralarim.yerAdi(nokta.latitude, nokta.longitude);
    if (!mounted) return;
    setState(() {
      _adAraniyor = false;
      _adNokta = nokta;
      _yerAdi = r?.$1;
      _yerYaka = r?.$2;
    });
  }

  Spot get _secim {
    final (n, d) = _yakin;
    if (d < 2) return n;
    if (!_ogren) return Spot.pin(_merkez.latitude, _merkez.longitude, n);
    final eski = Meralarim.yakinda(_merkez.latitude, _merkez.longitude);
    if (eski != null) return eski;
    // Yaka yalnızca İstanbul'un iki yakası arasında düzeltilir (Karadeniz / Marmara diğer bölgeler aynı kalır)
    final yaka = (n.side == Side.anadolu || n.side == Side.avrupa) ? _yerYaka : null;
    return Spot.pin(_merkez.latitude, _merkez.longitude, n, ad: _adGuncel ? _yerAdi : null, side: yaka);
  }

  Future<void> _konumum() async {
    setState(() => _konumAraniyor = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _soyle('Konum izni yok. Haritayı kaydırarak seçebilirsin.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)));
      _merkez = LatLng(pos.latitude, pos.longitude);
      _ctrl.move(_merkez, 14);
      setState(() {});
    } catch (_) {
      _soyle('Konum alınamadı. Haritayı kaydırarak seçebilirsin.');
    } finally {
      if (mounted) setState(() => _konumAraniyor = false);
    }
  }

  void _soyle(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _sec() async {
    if (_ogren && _yakin.$2 >= 2 && !_adGuncel) await _adBul();
    if (!mounted) return;
    var s = _secim;
    if (!s.side.public && !appState.isMember) {
      showMemberPrompt(context, '${s.side.label} meraları');
      return;
    }
    if (_ogren && s.ogrenilmis) {
      s = await Meralarim.ekle(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${s.name} Meralarım\'a eklendi. Tahminler bu noktaya göre hesaplanıyor.')));
      }
    }
    if (mounted) Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final (n, d) = _yakin;
    final uzak = d > 40;
    final sec = _secim;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baslik),
        actions: [
          SegmentedButton<HaritaKatman>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: HaritaKatman.uydu, label: Text('Uydu')),
              ButtonSegment(value: HaritaKatman.harita, label: Text('Harita')),
            ],
            selected: {_katman},
            onSelectionChanged: (v) => setState(() => _katman = v.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: _merkez,
            initialZoom: widget.baslangic == null ? 12 : 13,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (camera, _) {
              setState(() => _merkez = camera.center);
              _adBulZamanla();
            },
            onTap: (_, p) => _ctrl.move(p, _ctrl.camera.zoom),
          ),
          children: [
            if (_katman == HaritaKatman.uydu) ...[
              TileLayer(urlTemplate: _uyduUrl, userAgentPackageName: 'com.kiyidanav.kiyidanav', maxNativeZoom: 19),
              TileLayer(urlTemplate: _etiketUrl, userAgentPackageName: 'com.kiyidanav.kiyidanav', maxNativeZoom: 19),
            ] else
              TileLayer(urlTemplate: _osmUrl, userAgentPackageName: 'com.kiyidanav.kiyidanav', maxNativeZoom: 19),
            MarkerLayer(markers: [
              for (final s in spots)
                Marker(
                  point: LatLng(s.lat, s.lon),
                  width: 22,
                  height: 22,
                  child: GestureDetector(
                    onTap: () => _ctrl.move(LatLng(s.lat, s.lon), _ctrl.camera.zoom < 12 ? 13 : _ctrl.camera.zoom),
                    child: Container(
                      decoration: BoxDecoration(
                        color: s.name == n.name ? Tide.turuncu : Tide.derin,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
            ]),
            // 1.13.2: Meralarım (haritadan öğrenilen meralar)
            if (_ogren)
              MarkerLayer(markers: [
                for (final s in Meralarim.liste.value)
                  Marker(
                    point: LatLng(s.lat, s.lon),
                    width: 26,
                    height: 26,
                    child: GestureDetector(
                      onTap: () => _ctrl.move(LatLng(s.lat, s.lon), _ctrl.camera.zoom < 12 ? 13 : _ctrl.camera.zoom),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.push_pin, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
              ]),
            RichAttributionWidget(attributions: [
              if (_katman == HaritaKatman.uydu) const TextSourceAttribution('Esri, Maxar, Earthstar Geographics'),
              const TextSourceAttribution('OpenStreetMap katkıcıları'),
            ]),
          ],
        ),
        // Ortadaki iğne: harita kaydırıldıkça altındaki nokta seçilir
        const IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on, size: 48, color: Color(0xFFD93D1A), shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton.small(
            heroTag: 'konumum',
            backgroundColor: Colors.white,
            foregroundColor: Tide.derin,
            tooltip: 'Konumumu bul',
            onPressed: _konumAraniyor ? null : _konumum,
            child: _konumAraniyor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          d < 2 || !_ogren
                              ? (d < 2 ? n.name : '${n.name} yakını')
                              : (_adAraniyor && !_adGuncel ? 'Yer adı bulunuyor…' : sec.name),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    if (_ogren && d >= 2 && !uzak)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFE6F2E7), borderRadius: BorderRadius.circular(20)),
                        child: Text(sec.ogrenilmis && Meralarim.yakinda(sec.lat, sec.lon) != null ? 'Meralarım' : 'Yeni mera',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    uzak
                        ? 'İğne kıyıdan uzakta: en yakın mera ${n.name} (~${d.round()} km). Kıyıya yaklaştır.'
                        : d >= 2 && _ogren
                            ? '${sec.side.label} · tahminler bu noktaya göre · en yakın kayıtlı mera ${n.name} (~${d.toStringAsFixed(d < 10 ? 1 : 0)} km)'
                            : '${n.side.label} · en yakın mera ${n.name}${d >= 2 ? ' (~${d.toStringAsFixed(d < 10 ? 1 : 0)} km)' : ''}',
                    style: TextStyle(fontSize: 13, color: uzak ? Tide.mercan : const Color(0xFF6B6A60)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (widget.liste) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(const Spot(_listeIstegi, 0, 0, Side.anadolu)),
                          child: const Text('Listeden seç'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                        onPressed: uzak ? null : _sec,
                        icon: const Icon(Icons.check),
                        label: Text(_ogren && d >= 2 ? 'Mera olarak ekle ve seç' : widget.secYazisi),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
