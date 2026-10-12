import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_state.dart';
import 'mera.dart';
import 'overlays.dart';
import 'sea.dart';
import 'sea_card.dart';
import 'theme.dart';

/// Telefonun yaklaşık konumundan en yakın merayı bulur.
/// Konum yalnızca telefonda kullanılır; sunucuya veya başka bir yere gönderilmez.
class Locate {
  static const _autoKey = 'konum_otomatik_v1';

  /// Kullanıcı "konumumu kullan"ı açtıysa uygulama her açılışta en yakın merayı seçer
  static final auto = ValueNotifier<bool>(false);

  static double _km(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// En yakın nokta ve uzaklığı (km). [onlyPublic]: üye değilse yalnızca İstanbul yakaları.
  static (Spot, double) nearest(double lat, double lon, {bool onlyPublic = false}) {
    Spot best = spots.first;
    var dist = double.infinity;
    for (final s in spots) {
      if (onlyPublic && !s.side.public) continue;
      final d = _km(lat, lon, s.lat, s.lon);
      if (d < dist) {
        dist = d;
        best = s;
      }
    }
    return (best, dist);
  }

  static Future<void> loadPref() async {
    try {
      auto.value = (await SharedPreferences.getInstance()).getBool(_autoKey) ?? false;
    } catch (_) {}
  }

  static Future<void> _setAuto(bool v) async {
    auto.value = v;
    try {
      (await SharedPreferences.getInstance()).setBool(_autoKey, v);
    } catch (_) {}
  }

  /// İzin zaten verilmişse ve otomatik açıksa sessizce en yakın merayı seç (açılışta)
  static Future<void> silentUpdate() async {
    if (!auto.value) return;
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.always && p != LocationPermission.whileInUse) return;
      final pos = await _position();
      if (pos == null) return;
      final (spot, _) = nearest(pos.latitude, pos.longitude, onlyPublic: !appState.isMember);
      await saveSelectedSpot(spot);
    } catch (_) {}
  }

  static Future<Position?> _position() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 60) return last;
    } catch (_) {}
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
    );
  }

  /// "Konumumu kullan" düğmesi: açıklama → izin → en yakın mera
  static Future<void> useMyLocation(BuildContext context) async {
    void say(String m) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        say('Telefonun konum servisi kapalı. Açıp tekrar dene.');
        await Geolocator.openLocationSettings();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppDialog(
            closeResult: false,
            icon: const Icon(Icons.my_location, color: Tide.turuncu, size: 34),
            title: 'Sana en yakın merayı gösterelim',
            content: const Text('Yaklaşık konumun yalnızca telefonunda, en yakın kıyı noktasını seçmek için '
                'kullanılır. Hiçbir yere gönderilmez ve saklanmaz.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Şimdi değil')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Devam'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        say('Konum izni kapalı. Telefon ayarlarından KıyıdanAv için konum iznini açabilirsin.');
        await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) return;
      say('Konumun bulunuyor…');
      final pos = await _position();
      if (pos == null) {
        say('Konum alınamadı, listeden seçebilirsin.');
        return;
      }
      final member = appState.isMember;
      final (all, distAll) = nearest(pos.latitude, pos.longitude);
      final (pub, distPub) = nearest(pos.latitude, pos.longitude, onlyPublic: true);
      await _setAuto(true);
      if (!member && !all.side.public) {
        await saveSelectedSpot(pub);
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showMemberPrompt(context, 'Sana en yakın mera (${all.name}, ~${distAll.round()} km)');
        }
        return;
      }
      await saveSelectedSpot(member ? all : pub);
      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final d = member ? distAll : distPub;
      say('En yakın mera: ${(member ? all : pub).name} (~${d < 1 ? '1' : d.round()} km)');
    } catch (_) {
      say('Konum alınamadı, listeden seçebilirsin.');
    }
  }

  static Future<void> manualPick(Spot s) async {
    await _setAuto(false); // elle seçildi: açılışta konuma göre değiştirme
    await saveSelectedSpot(s);
  }
}

/// Mera seçici: üstte "Konumumu kullan", altında bölge bölge kıyı noktaları
Future<void> showSpotPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(children: [
              const Expanded(child: Text('Konum seç', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              CloseX(onTap: () => Navigator.of(ctx).pop()),
            ]),
          ),
          if (Api.config.features.location) ...[
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Tide.turuncu, child: Icon(Icons.my_location, color: Colors.white)),
            title: const Text('Bulunduğum konumu kullan', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Sana en yakın merayı otomatik seçer'),
            onTap: () {
              Navigator.of(ctx).pop();
              Locate.useMyLocation(context);
            },
          ),
          const Divider(),
          ],
          for (final side in Side.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(children: [
                Text(side.label,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.zeytinKoyu, fontSize: 14)),
                if (!side.public && !appState.isMember) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline, size: 15, color: Tide.misina),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in spotsOf(side))
                  ChoiceChip(
                    label: Text(s.name),
                    selected: selectedSpot.value.name == s.name,
                    selectedColor: Tide.somon,
                    onSelected: (_) {
                      Navigator.of(ctx).pop();
                      if (!side.public && !appState.isMember) {
                        showMemberPrompt(context, '${side.label} meraları');
                        return;
                      }
                      Locate.manualPick(s);
                    },
                  ),
              ]),
            ),
          ],
        ],
      ),
    ),
  );
}

/// "📍 Konum: Kartal · Anadolu Yakası   Değiştir" şeridi
class LocationBar extends StatelessWidget {
  const LocationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Spot>(
      valueListenable: selectedSpot,
      builder: (context, spot, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showSpotPicker(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E2D6)),
              ),
              child: Row(children: [
                const Icon(Icons.place, color: Tide.turuncu),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: Locate.auto,
                      builder: (_, a, __) => Text(a ? 'Konum (bulunduğun yere göre)' : 'Konum',
                          style: const TextStyle(fontSize: 11.5, color: Tide.misina)),
                    ),
                    Text('${spot.name} · ${spot.side.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Bulunduğum konumu kullan',
                  onPressed: () => Locate.useMyLocation(context),
                  icon: const Icon(Icons.my_location, color: Tide.zeytinKoyu),
                ),
                const Text('Değiştir', style: TextStyle(color: Tide.turuncu, fontWeight: FontWeight.w700)),
                const Icon(Icons.expand_more, color: Tide.turuncu),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
