import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'app_state.dart';
import 'locate.dart';
import 'mera.dart';
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
/// İğne kayıtlı bir meraya 2 km'den yakınsa o mera, değilse "X yakını" noktası seçilir
/// (deniz ve kıyı bilgileri en yakın meradan, hava tahmini iğnenin yerinden alınır).
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

  Spot get _secim {
    final (n, d) = _yakin;
    return d < 2 ? n : Spot.pin(_merkez.latitude, _merkez.longitude, n);
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

  void _sec() {
    final s = _secim;
    if (!s.side.public && !appState.isMember) {
      showMemberPrompt(context, '${s.side.label} meraları');
      return;
    }
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final (n, d) = _yakin;
    final uzak = d > 40;
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
            onPositionChanged: (camera, _) => setState(() => _merkez = camera.center),
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
                  Text(d < 2 ? n.name : '${n.name} yakını',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    uzak
                        ? 'İğne kıyıdan uzakta: en yakın mera ${n.name} (~${d.round()} km). Kıyıya yaklaştır.'
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
                        label: Text(widget.secYazisi),
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
