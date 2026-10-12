import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../mera.dart';
import '../theme.dart';

/// Balıkçı düğümü (yönetim panelinden gelir)
class Knot {
  final String name;
  final String group;
  final String use;
  final List<String> steps;
  final String video; // YouTube video kimliği (11 karakter) veya boş
  final int level; // 1 kolay – 3 zor

  const Knot(
      {required this.name, this.group = '', this.use = '', this.steps = const [], this.video = '', this.level = 1});

  factory Knot.fromJson(Map<String, dynamic> j) => Knot(
        name: '${j['ad'] ?? ''}',
        group: '${j['grup'] ?? ''}',
        use: '${j['kullanim'] ?? ''}',
        steps: ((j['adimlar'] as List?) ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(),
        video: RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch('${j['video'] ?? ''}') ? '${j['video']}' : '',
        level: (j['zorluk'] is num) ? (j['zorluk'] as num).clamp(1, 3).toInt() : 1,
      );

  Uri get videoUri => video.isNotEmpty
      ? Uri.https('www.youtube.com', '/watch', {'v': video})
      : Uri.https('www.youtube.com', '/results', {'search_query': '$name balıkçı düğümü nasıl bağlanır'});
}

class KnotService {
  static List<Knot>? _cache;

  static Future<List<Knot>> load({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {'a': 'dugumler'});
    final r = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map || j['ok'] != true) throw Exception('Düğümler alınamadı');
    _cache = ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Knot.fromJson(Map<String, dynamic>.from(e)))
        .where((k) => k.name.isNotEmpty)
        .toList();
    return _cache!;
  }
}

/// Düğümler: üye girişinden sonra açılır
class KnotsScreen extends StatefulWidget {
  const KnotsScreen({super.key});

  @override
  State<KnotsScreen> createState() => _KnotsScreenState();
}

class _KnotsScreenState extends State<KnotsScreen> {
  late Future<List<Knot>> _future = KnotService.load();
  String _group = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balıkçı Düğümleri')),
      body: MemberGate(
        title: 'Düğüm rehberi üyelere özel',
        message: 'Ücretsiz üye ol; iğne, fırdöndü, misina ekleme ve köstek düğümlerini adım adım ve videolu öğren.',
        child: FutureBuilder<List<Knot>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tide.zeytin));
            }
            if (snap.hasError || snap.data == null) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() => _future = KnotService.load(force: true)),
                  child: const Text('Düğümler yüklenemedi — tekrar dene'),
                ),
              );
            }
            final all = snap.data!;
            final groups = <String>{for (final k in all) if (k.group.isNotEmpty) k.group}.toList();
            final list = _group.isEmpty ? all : all.where((k) => k.group == _group).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (groups.length > 1)
                  SizedBox(
                    height: 44,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final g in ['', ...groups])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(g.isEmpty ? 'Tümü' : g),
                            selected: _group == g,
                            selectedColor: Tide.somon,
                            onSelected: (_) => setState(() => _group = g),
                          ),
                        ),
                    ]),
                  ),
                const SizedBox(height: 8),
                for (final k in list) _KnotCard(k),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KnotCard extends StatelessWidget {
  final Knot k;
  const _KnotCard(this.k);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.gesture, color: Tide.turuncu),
          ),
          title: Text(k.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          subtitle: Row(children: [
            if (k.group.isNotEmpty)
              Flexible(child: Text(k.group, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
            const SizedBox(width: 8),
            for (var i = 0; i < 3; i++)
              Icon(Icons.circle, size: 7, color: i < k.level ? Tide.turuncu : const Color(0xFFE0DCCF)),
          ]),
          children: [
            if (k.use.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(k.use, style: const TextStyle(fontSize: 14, height: 1.45)),
              ),
            const SizedBox(height: 10),
            for (var i = 0; i < k.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Tide.zeytin, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(k.steps[i], style: const TextStyle(fontSize: 14, height: 1.4))),
                ]),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: k.video.isNotEmpty ? const Color(0xFFD32F2F) : Tide.zeytin),
                onPressed: () => launchUrl(k.videoUri, mode: LaunchMode.externalApplication),
                icon: Icon(k.video.isNotEmpty ? Icons.play_circle_fill : Icons.search),
                label: Text(k.video.isNotEmpty ? 'Videoyu izle' : 'YouTube\'da video ara'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mera Bilgisi sekmesindeki giriş kartı
class KnotsEntry extends StatelessWidget {
  const KnotsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: Tide.zeytinKoyu,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KnotsScreen())),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.gesture, color: Tide.turuncu, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Balıkçı Düğümleri',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('İğne, fırdöndü ve misina ekleme — adım adım, videolu',
                      style: TextStyle(color: Color(0xFFE3E0CF), fontSize: 12.5)),
                ]),
              ),
              Icon(Icons.chevron_right, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}
