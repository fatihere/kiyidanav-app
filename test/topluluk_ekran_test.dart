// Topluluk ekranları (Av bildir, Fishkrok, Badimi bul, Profilim) gerçek akışla açılır mı?
// Telefonda "dokununca açılacak gibi olup pasife düşme" hatası için: her adımda ekrandaki
// yazılar ve yakalanan hatalar test çıktısına yazılır.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiyidanav/app_state.dart';
import 'package:kiyidanav/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _anahtar() {
  final govde = base64Url
      .encode(utf8.encode(jsonEncode({'u': 123, 'e': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30 * 86400})))
      .replaceAll('=', '');
  return '$govde.imza';
}

http.Response _json(Object o) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), 200, headers: {'content-type': 'application/json; charset=utf-8'});

final _istemci = MockClient((r) async {
  final u = r.url.toString();
  final a = r.url.queryParameters['a'] ?? '';
  if (u.contains('mobil-topluluk.php')) {
    switch (a) {
      case 'profil':
        return _json({'ok': true, 'ad': 'Fatih E.', 'var': true, 'yas': '35', 'kamis': ['Spin'], 'il': 'İstanbul', 'ilce': 'Kartal', 'instagram': 'fatih', 'avatar': ''});
      case 'fk_akis':
        return _json({'ok': true, 'items': [], 'sayfa': 1, 'devam': false});
      case 'badi_yakin':
        return _json({'ok': true, 'items': [], 'benim': null, 'engellediklerim': []});
      default:
        return _json({'ok': true, 'items': []});
    }
  }
  if (u.contains('mobil-api.php')) {
    if (a == 'config') return _json({'ok': true, 'eklentiler': {}});
    return _json({'ok': true, 'items': [], 'spots': {}});
  }
  if (u.contains('mobil-av.php')) return _json({'ok': true, 'items': []});
  return http.Response('{}', 404);
});

void main() {
  late List<String> hatalar;
  late FlutterExceptionHandler? eski;

  setUp(() {
    hatalar = [];
    eski = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      // Testte ağ görselleri yüklenemez; bunlar gerçek hata değil
      if (d.library == 'image resource service' || s.contains('NetworkImage') || s.contains('HTTP request failed')) return;
      hatalar.add('${d.library}: $s\n${d.context ?? ''}');
    };
  });
  tearDown(() => FlutterError.onError = eski);

  Future<void> bekle(WidgetTester t, [int sn = 3]) async {
    for (var i = 0; i < sn * 4; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }

  void yaz(WidgetTester t, String adim) {
    final yazilar = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .take(40)
        .join(' | ');
    final ex = t.takeException();
    // ignore: avoid_print
    print('=== $adim\nEKRAN: $yazilar${ex != null ? '\nİSTİSNA: $ex' : ''}${hatalar.isNotEmpty ? '\nHATALAR:\n${hatalar.join('\n---\n')}' : ''}');
    if (ex != null) hatalar.add('$adim: $ex');
  }

  for (final uye in [true, false]) {
    testWidgets('Topluluk ekranları (üye: $uye)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'member_v1': uye,
        if (uye) 'av_anahtar_v1': _anahtar(),
        'profil_soruldu_v1': true,
        'profil_v1': '35|Spin|İstanbul|Kartal',
        'konum_ilk_sorgu_v112': true,
      });
      await http.runWithClient(() async {
        await appState.load();
        await tester.pumpWidget(const KiyidanAvApp());
        await bekle(tester);
        yaz(tester, 'açılış');

        // İlk açılış formu çıktıysa kapat
        final simdiDegil = find.text('Şimdi değil');
        if (simdiDegil.evaluate().isNotEmpty) {
          await tester.tap(simdiDegil.first);
          await bekle(tester, 1);
        }

        final nav = find.byType(NavigationBar);
        Future<void> sekme(String ad) async {
          final f = find.descendant(of: nav, matching: find.text(ad));
          if (f.evaluate().isEmpty) {
            // ignore: avoid_print
            print('Sekme yok: $ad');
            return;
          }
          await tester.tap(f.first);
          await bekle(tester);
        }

        Future<void> dokun(String adim, Finder f) async {
          if (f.evaluate().isEmpty) {
            // ignore: avoid_print
            print('=== $adim: düğme bulunamadı');
            return;
          }
          await tester.ensureVisible(f.first);
          await tester.pump();
          await tester.tap(f.first, warnIfMissed: false);
          await bekle(tester);
          yaz(tester, adim);
          // Açılan sayfa / pencereyi kapat
          final nav2 = tester.state<NavigatorState>(find.byType(Navigator).first);
          await nav2.maybePop();
          await bekle(tester, 1);
        }

        await sekme('Fishkrok');
        yaz(tester, 'Fishkrok sekmesi');
        await dokun('Fishkrok › Av bildir (üst düğme)', find.widgetWithText(FilledButton, 'Av bildir'));
        await dokun('Fishkrok › Profilim', find.byTooltip('Profilim'));

        await sekme('Hesabım');
        yaz(tester, 'Hesabım sekmesi');
        await dokun('Hesabım › Profilim', find.textContaining('Profilim'));
        await dokun('Hesabım › Badimi bul', find.text('Badimi bul'));
        await dokun('Hesabım › Mesajlarım', find.text('Mesajlarım'));

        await sekme('Mera Bilgisi');
        await bekle(tester, 4);
        yaz(tester, 'Mera Bilgisi sekmesi');
        await dokun('Mera › Av bildir', find.textContaining('Av bildir'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 15));
      }, () => _istemci);

      expect(hatalar, isEmpty, reason: hatalar.join('\n\n'));
    });
  }
}
