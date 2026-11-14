import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'catches.dart';
import 'config.dart';
import 'theme.dart';
import 'updates.dart';

/// 1.17.2: Hesabım › "Görüşünü yaz, hediye kupon kazan".
/// Kupon, uygulama içi geri bildirim formuna teşekkürdür; mağaza puanına/yorumuna BAĞLI DEĞİLDİR
/// (Google Play ve App Store yorum karşılığı ödülü yasaklar). Verilen puan ne olursa olsun kupon aynıdır.
class GeriBildirimKupon {
  final String kod;
  final int oran;
  final String son;
  final bool kullanildi;
  const GeriBildirimKupon(this.kod, this.oran, this.son, this.kullanildi);

  static GeriBildirimKupon? oku(Object? j) {
    if (j is! Map || (j['kod'] ?? '').toString().isEmpty) return null;
    return GeriBildirimKupon(j['kod'].toString(), (j['oran'] as num?)?.toInt() ?? 5, (j['son'] ?? '').toString(), j['kullanildi'] == true);
  }

  /// "2027-02-13" → "13.02.2027"
  String get sonTarih {
    final p = son.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : son;
  }
}

class GeriBildirimApi {
  static Uri uri(String a) => Uri.parse('${AppConfig.siteUrl}mobil-geri-bildirim.php').replace(queryParameters: {'a': a});

  /// (kupon açık mı, oran, daha önce alınan kupon)
  static Future<(bool, int, GeriBildirimKupon?)> durum(String token, {http.Client? c}) async {
    final cl = c ?? http.Client();
    try {
      final r = await cl.get(uri('durum'), headers: {'Accept': 'application/json', 'X-Av-Anahtar': token}).timeout(const Duration(seconds: 10));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true) {
        return (j['kupon_acik'] != false, (j['oran'] as num?)?.toInt() ?? 5, GeriBildirimKupon.oku(j['kupon']));
      }
    } catch (_) {
    } finally {
      if (c == null) cl.close();
    }
    return (true, 5, null);
  }

  /// Başarılıysa (null hata, kupon, yeni mi); değilse hata metni
  static Future<(String?, GeriBildirimKupon?, bool)> gonder(String token, int puan, String begendi, String eksik, {http.Client? c}) async {
    final cl = c ?? http.Client();
    try {
      final r = await cl
          .post(uri('gonder'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'X-Av-Anahtar': token},
              body: jsonEncode({
                'puan': puan,
                'begendi': begendi,
                'eksik': eksik,
                'platform': Platform.isIOS ? 'ios' : 'android',
                'surum': AppUpdate.name,
              }))
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['ok'] == true) return (null, GeriBildirimKupon.oku(j['kupon']), j['yeni'] == true);
      if (j is Map) return ((j['error'] ?? 'Gönderilemedi.').toString(), GeriBildirimKupon.oku(j['kupon']), false);
    } catch (_) {
    } finally {
      if (c == null) cl.close();
    }
    return ('Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.', null, false);
  }
}

class GeriBildirimEkrani extends StatefulWidget {
  const GeriBildirimEkrani({super.key});

  static Future<void> ac(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GeriBildirimEkrani()));

  @override
  State<GeriBildirimEkrani> createState() => _GeriBildirimEkraniState();
}

class _GeriBildirimEkraniState extends State<GeriBildirimEkrani> {
  final _begendi = TextEditingController();
  final _eksik = TextEditingController();
  int _puan = 0;
  bool _yukleniyor = true, _gonderiliyor = false;
  bool _kuponAcik = true;
  int _oran = 5;
  GeriBildirimKupon? _kupon;
  String? _token;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _begendi.dispose();
    _eksik.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _token = memberNotifier.value ? await CatchService.token() : null;
    if (_token != null) {
      final (acik, oran, kupon) = await GeriBildirimApi.durum(_token!);
      _kuponAcik = acik;
      _oran = oran;
      _kupon = kupon;
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _gonder() async {
    final m = ScaffoldMessenger.of(context);
    if (_puan == 0) {
      m.showSnackBar(const SnackBar(content: Text('Önce 1–5 arası puan seç.')));
      return;
    }
    if ((_begendi.text + _eksik.text).trim().length < 15) {
      m.showSnackBar(const SnackBar(content: Text('Birkaç cümleyle yaz: neyi beğendin, neyi eklememizi istersin?')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _gonderiliyor = true);
    final (hata, kupon, yeni) = await GeriBildirimApi.gonder(_token!, _puan, _begendi.text.trim(), _eksik.text.trim());
    if (!mounted) return;
    setState(() {
      _gonderiliyor = false;
      if (kupon != null) _kupon = kupon;
    });
    if (hata != null) {
      m.showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    _begendi.clear();
    _eksik.clear();
    setState(() => _puan = 0);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.favorite, color: Tide.turuncu, size: 36),
        title: const Text('Teşekkürler!'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Görüşün bize ulaştı; uygulamayı geliştirirken dikkate alacağız.'),
          if (yeni && kupon != null) ...[
            const SizedBox(height: 12),
            _KuponKutusu(kupon: kupon),
          ],
          const SizedBox(height: 12),
          const Text('İstersen mağazada da puan verip yorum yazabilirsin; diğer balıkçıların uygulamayı bulmasına yardım eder. '
              '(İsteğe bağlı, kuponla ilgisi yok.)',
              style: TextStyle(fontSize: 13, color: Color(0xFF77766A))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Kapat')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Tide.turuncu),
            onPressed: () {
              Navigator.of(c).pop();
              AppUpdate.degerlendir();
            },
            icon: const Icon(Icons.star_rate_outlined),
            label: Text(Platform.isIOS ? 'App Store' : 'Google Play'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Görüşünü yaz')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _token == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Görüşünü yazmak ve hediye kuponu almak için önce Hesabım\'dan üye girişi yap.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                  if (_kupon != null) ...[
                    _KuponKutusu(kupon: _kupon!),
                    const SizedBox(height: 16),
                  ] else if (_kuponAcik)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(14)),
                      child: Text('KıyıdanAv hakkındaki görüşünü yaz, teşekkür olarak kiyidanav.com alışverişinde geçerli '
                          '%$_oran indirim kuponu hemen hesabına tanımlansın. Olumlu ya da olumsuz, her görüş aynı kuponu kazanır.',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  const Text('Uygulamaya kaç puan verirsin?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        key: ValueKey('yildiz$i'),
                        iconSize: 40,
                        onPressed: () => setState(() => _puan = i),
                        icon: Icon(i <= _puan ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF4A522)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _begendi,
                    maxLength: 600,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'En çok neyi beğendin?', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _eksik,
                    maxLength: 600,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Neyi eklememizi ya da düzeltmemizi istersin?', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Tide.turuncu, minimumSize: const Size.fromHeight(50)),
                    onPressed: _gonderiliyor ? null : _gonder,
                    icon: _gonderiliyor
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: const Text('Gönder'),
                  ),
                  const SizedBox(height: 10),
                  const Text('Yazdıkların yalnızca KıyıdanAv ekibine gider, herkese açık yayınlanmaz.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF77766A))),
                ]),
    );
  }
}

class _KuponKutusu extends StatelessWidget {
  final GeriBildirimKupon kupon;
  const _KuponKutusu({required this.kupon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9FD8B3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🎁 %${kupon.oran} hediye kuponun', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SelectableText(kupon.kod,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF127A3E))),
          ),
          IconButton(
            tooltip: 'Kopyala',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: kupon.kod));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kupon kodu kopyalandı')));
            },
          ),
        ]),
        Text(
          kupon.kullanildi
              ? 'Bu kupon kullanıldı.'
              : 'kiyidanav.com\'da üye girişi yapıp sepette "Kupon kodu" alanına yaz. Tek seferlik'
                  '${kupon.son.isNotEmpty ? ', ${kupon.sonTarih} tarihine kadar geçerli' : ''}.',
          style: const TextStyle(fontSize: 13),
        ),
      ]),
    );
  }
}
