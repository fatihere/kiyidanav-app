// 1.17.0: Kıyıdabiri yapay zekâ döngüsü — araçlar uygulama verisiyle çalışır, rakamlar Mera Bilgisi ile aynıdır
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/kiyidabiri_beyin.dart';

import 'kiyidabiri_test.dart' show SahteVeri;

class SahteYz implements KbYz {
  final List<Map<String, dynamic>> yanitlar;
  final istekler = <List<Map<String, dynamic>>>[];
  SahteYz(this.yanitlar);
  @override
  Future<Map<String, dynamic>> iste(List<Map<String, dynamic>> mesajlar) async {
    istekler.add(List.of(mesajlar));
    return yanitlar.removeAt(0);
  }
}

Map<String, dynamic> _arac(String id, String ad, Map<String, dynamic> girdi) => {
      'durdu': 'tool_use',
      'icerik': [
        {'type': 'thinking', 'thinking': '', 'signature': 'imza'},
        {'type': 'tool_use', 'id': id, 'name': ad, 'input': girdi},
      ],
    };
Map<String, dynamic> _metin(String t) => {
      'durdu': 'end_turn',
      'icerik': [
        {'type': 'text', 'text': t}
      ],
    };

void main() {
  test('yarın sorusu: araç yarının verisini döndürür, geçmiş ve düşünme blokları korunur', () async {
    final yz = SahteYz([_arac('a1', 'mera_durumu', {'mera': 'Kartal', 'gun': 1}), _metin('Kartal yarın rüzgârlı, 28 km/s.')]);
    final s = KbYzSohbet(KiyidabiriBeyin(SahteVeri()), yz);
    final y = await s.yanitla('kartal yarın nasıl', simdi: DateTime(2026, 11, 6, 9));
    expect(y!.metin, 'Kartal yarın rüzgârlı, 28 km/s.');
    expect(y.niyet, 'yz');
    expect(y.spot?.name, 'Kartal');
    expect(y.secenekler.map((e) => e.etiket), contains('Mera bilgisini aç'));
    // ilk istek bağlam satırıyla
    expect(yz.istekler.first.first['content'], startsWith('[Bağlam: bugün 6.11.2026 Cuma'));
    // araç sonucu uygulamanın yarın hesabı
    final sonuc = (yz.istekler[1].last['content'] as List).first as Map;
    expect(sonuc['tool_use_id'], 'a1');
    expect(sonuc['content'], contains('Yarın (7.11)'));
    expect(sonuc['content'], contains('28 km/s'));
    // geçmiş: user, assistant(thinking+tool_use), user(tool_result), assistant(text)
    expect(s.gecmis.length, 4);
    expect(((s.gecmis[1]['content'] as List).first as Map)['signature'], 'imza');
  });

  test('bilinmeyen mera uydurulmaz; reddedilirse kural tabanlıya düşülür; tekne talebi adımlara geçer', () async {
    final b = KiyidabiriBeyin(SahteVeri());
    final yz = SahteYz([
      _arac('a1', 'mera_durumu', {'mera': 'Zzzyok', 'gun': 0}),
      _metin('Bu yeri bulamadım, haritadan seçer misin?'),
      {'durdu': 'refusal', 'icerik': []},
      _arac('a2', 'tekne_avi', {}),
    ]);
    final s = KbYzSohbet(b, yz);
    final y = await s.yanitla('zzzyok nasil');
    expect(((yz.istekler[1].last['content'] as List).first as Map)['content'], startsWith('BULUNAMADI'));
    expect(y!.secenekler.map((e) => e.etiket), contains('Haritadan seç'));
    expect(await s.yanitla('x'), isNull);
    final t = await s.yanitla('tekneyle çıkmak istiyorum');
    expect(t!.niyet, 'tekne');
    expect(b.adim, KbAdim.tekneSor);
  });

  test('bilgi yoksa yanıt araştırma listesine düşer (niyet bilinmiyor)', () async {
    final yz = SahteYz([_arac('a1', 'site_bilgisi', {'soru': 'qqq wwww eeee'}), _metin('Bunu bilmiyorum, temsilciye bağlayayım mı?')]);
    final y = await KbYzSohbet(KiyidabiriBeyin(SahteVeri()), yz).yanitla('qqq wwww eeee');
    expect(y!.niyet, 'bilinmiyor');
  });
}
