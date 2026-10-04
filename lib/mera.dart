import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'config.dart';
import 'sea.dart';
import 'theme.dart';
import 'web_page_screen.dart';

/// Bir meranın kıyıdan açığa kesit bilgisi.
/// Derinlikler EMODnet Bathymetry modelinden alınan TAHMİNİ değerlerdir;
/// dip yapısı ve notlar yönetim panelinden elle girilir.
class MeraInfo {
  /// (kıyıdan mesafe m, derinlik m)
  final List<MapEntry<int, double>> profile;
  final String dip; // ör. "Kaya → çakıl → kum"
  final String note; // balıkçılık notu
  final String source;

  const MeraInfo({this.profile = const [], this.dip = '', this.note = '', this.source = ''});

  bool get isEmpty => profile.isEmpty && dip.isEmpty && note.isEmpty;

  factory MeraInfo.fromJson(Map<String, dynamic> j) {
    final p = <MapEntry<int, double>>[];
    for (final e in (j['d'] as List? ?? const [])) {
      if (e is List && e.length >= 2 && e[0] is num && e[1] is num) {
        p.add(MapEntry((e[0] as num).round(), (e[1] as num).toDouble()));
      }
    }
    return MeraInfo(
      profile: p,
      dip: (j['dip'] ?? '').toString().trim(),
      note: (j['not'] ?? '').toString().trim(),
      source: (j['kaynak'] ?? '').toString().trim(),
    );
  }

  /// Sarı kutudaki kısa özet
  String get summary {
    final parts = <String>[];
    if (dip.isNotEmpty) parts.add(dip.length > 18 ? '${dip.substring(0, 17)}…' : dip);
    if (profile.isNotEmpty) {
      final e = profile.length > 1 ? profile[profile.length - 1] : profile.first;
      parts.add('${e.key} m: ~${e.value.round()} m');
    }
    return parts.join(' · ');
  }
}

class MeraService {
  static Map<String, MeraInfo>? _cache;
  static Future<Map<String, MeraInfo>>? _loading;

  static Future<Map<String, MeraInfo>> load() {
    if (_cache != null) return Future.value(_cache);
    return _loading ??= _fetch();
  }

  static Future<Map<String, MeraInfo>> _fetch() async {
    try {
      final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'mera'});
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      final out = <String, MeraInfo>{};
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final m = (j is Map && j['spots'] is Map) ? j['spots'] as Map : const {};
        m.forEach((k, v) {
          if (v is Map<String, dynamic>) out[k.toString()] = MeraInfo.fromJson(v);
        });
      }
      _cache = out;
      return out;
    } catch (_) {
      _loading = null; // bir sonraki denemede yeniden dene
      return const {};
    }
  }

  static Future<MeraInfo?> of(Spot s) async {
    final m = await load();
    final i = m[s.name];
    return (i == null || i.isEmpty) ? null : i;
  }
}

void openLogin(BuildContext context, {bool register = false}) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebPageScreen(
          title: register ? 'Üye ol' : 'Giriş yap',
          route: register ? 'account/register' : 'account/login',
          homeAfterLogin: true)));
}

/// Üye girişi gerektiren bölümleri sarar. Giriş yapılmamışsa tanıtım ve giriş/üyelik düğmeleri gösterir.
class MemberGate extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;
  const MemberGate({
    super.key,
    required this.child,
    this.title = 'Tüm mera bilgileri üyelere özel',
    this.message = 'Ücretsiz üye ol; av verimliliği, en verimli saatler, 7 günlük tahmin, '
        'kıyı derinlik ve dip yapısı bilgileri ile Karadeniz, Marmara, Trakya ve Ege meralarına eriş.',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: memberNotifier,
      builder: (context, member, _) => member ? child : _locked(context),
    );
  }

  Widget _locked(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Tide.derin, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Tide.turuncu, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFBFD6D1), fontSize: 14, height: 1.4)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
                    onPressed: () => openLogin(context),
                    child: const Text('Giriş yap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                    onPressed: () => openLogin(context, register: true),
                    child: const Text('Ücretsiz üye ol'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
}

/// Kilitli bir bölgeye dokunulduğunda kısa davet
void showMemberPrompt(BuildContext context, String what) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: MemberGate(
        title: '$what üyelere özel',
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

/// Deniz kartındaki sarı alan: yalnızca üyelere ve verisi olan meralarda görünür
class MeraStat extends StatelessWidget {
  final Spot spot;
  const MeraStat({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: memberNotifier,
      builder: (context, member, _) {
        if (!member) return const SizedBox.shrink();
        return FutureBuilder<MeraInfo?>(
          future: MeraService.of(spot),
          builder: (context, snap) {
            final info = snap.data;
            if (info == null) return const SizedBox.shrink();
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showMeraSheet(context, spot, info),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD54F)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Dip / derinlik', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5)),
                    SizedBox(width: 3),
                    Icon(Icons.chevron_right, color: Color(0xFFFFD54F), size: 14),
                  ]),
                  Text(info.summary,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

void showMeraSheet(BuildContext context, Spot spot, MeraInfo info) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tide.derin,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Text('${spot.name} · kıyıdan açığa kesit',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(spot.side.label, style: const TextStyle(color: Color(0xFF9FC4BD), fontSize: 13)),
          const SizedBox(height: 14),
          if (info.profile.isNotEmpty) ...[
            for (final e in info.profile)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(
                      width: 110,
                      child: Text('Kıyıdan ${e.key} m',
                          style: const TextStyle(color: Color(0xFFBFD6D1), fontSize: 14))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (e.value / 30).clamp(0.05, 1.0),
                        minHeight: 8,
                        color: const Color(0xFF4FC3F7),
                        backgroundColor: const Color(0xFF0A2F36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('~${e.value.toStringAsFixed(e.value < 10 ? 1 : 0)} m',
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            const SizedBox(height: 10),
          ],
          if (info.dip.isNotEmpty) _row(Icons.layers_outlined, 'Dip yapısı', info.dip),
          if (info.note.isNotEmpty) _row(Icons.set_meal_outlined, 'Balıkçılık notu', info.note),
          const SizedBox(height: 8),
          Text(
            info.source.isNotEmpty
                ? 'Kaynak: ${info.source}. Derinlikler tahminidir; kıyıya yakın kaya ve dolgu topukları modelde görünmeyebilir.'
                : 'Derinlikler tahminidir; kıyıya yakın kaya ve dolgu topukları modelde görünmeyebilir.',
            style: const TextStyle(color: Color(0xFF8FB0AA), fontSize: 11.5, height: 1.35),
          ),
        ]),
      ),
    ),
  );
}

Widget _row(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Tide.turuncu, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFF9FC4BD), fontSize: 12)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
          ]),
        ),
      ]),
    );
