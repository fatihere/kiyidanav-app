import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyidanav/freshwater.dart';
import 'package:kiyidanav/kiyidabiri.dart';
import 'package:kiyidanav/kiyidabiri_beyin.dart';
import 'package:kiyidanav/models.dart';
import 'package:kiyidanav/sea.dart';

import 'kiyidabiri_test.dart' show SahteVeri;

/// 22.11.2026 sohbet kayıtlarındaki hatalar: "Yenikapı balık durumu" → Balık Gölü (Ağrı); surf seti isteği → yetersiz yanıt
class _Veri extends SahteVeri {
  final aramalar = <String>[];
  @override
  List<Spot> denizMeralari() => [pin, ...spots];
  @override
  Future<FwData?> tatliSu() async =>
      FwData.fromJson(jsonDecode(File('assets/data/tatli_su.json').readAsStringSync()) as Map<String, dynamic>);

  static const _urunler = [
    ProductCard(id: 61764, name: 'ICON-IC Drakion 8000 Red Surf Olta Makinesi Kampanya Seti', price: 15150, special: 12500),
    ProductCard(id: 61500, name: 'Captain 1657 Excalibo PT 420cm 3 Parça Surf Kamış 100-250gr Atar Kampanya Seti', price: 5487.82, special: 4950),
    ProductCard(id: 61062, name: 'ICON-IC Castira 4000 DC Olta Makarası - Spin & Surf Kampanya Seti', price: 4130.5),
    ProductCard(id: 61344, name: 'Oslo Crome Surf 420cm 70-250gr Ryuji Momentum 10000 Surf Olta Seti', price: 8549),
    ProductCard(id: 61762, name: 'Remixon Monster 7000 420cm Profesyonel Surf Olta Seti', price: 2999, inStock: false),
    ProductCard(id: 1948, name: 'Andoutdoor Plaj Raketi Seti-SURFING', price: 156),
    ProductCard(id: 61767, name: 'Oslo Zen Pro 274cm Spin Olta Kamışı Kampanya Seti', price: 7122, special: 6000),
    ProductCard(id: 58619, name: 'ICON-IC Power Force 8000 Surf Olta Makinesi', price: 6150),
  ];
  @override
  Future<List<ProductCard>> urunAra(String q) async {
    aramalar.add(q);
    final k = kbNorm(q).split(' ').first;
    return _urunler.where((u) => kbNorm(u.name).contains(k)).toList();
  }

  @override
  Future<String> urunAciklama(int id) async => id == 61062
      ? 'Set değeri 4.130,50 TL. Set içeriği\nICON-IC Castira 4000 DC4.130,50 TLSet değeri4.130,50 TL'
      : 'Set içeriği\nKamış7.140,00 TLMakine7.080,00 TLİp510,00 TLSet değeri15.150,00 TL';
}

Future<KiyidabiriBeyin> _beyin([_Veri? v]) async {
  final b = KiyidabiriBeyin(v ?? _Veri());
  await b.hazirla();
  return b;
}

void main() {
  test('Yenikapı sorusu Balık Gölü değil Yenikapı', () async {
    for (final soru in ['Yeni kapı balık durumu nedir', 'İstanbul Yenikapı balık durumu nedir', 'yenikapıda balık var mı']) {
      final y = await (await _beyin()).yanitla(soru);
      expect(y.niyet, 'mera', reason: soru);
      expect(y.spot?.name, 'Yenikapı', reason: soru);
      expect(y.metin, isNot(contains('Balık Gölü')), reason: soru);
    }
    expect((await (await _beyin()).yanitla('Rumeli feneri yarın nasıl')).spot?.name, 'Rumelifeneri');
    // Göl bütün adıyla sorulursa yine göl
    expect((await (await _beyin()).yanitla('balık gölü')).metin, contains('Balık Gölü'));
    expect((await (await _beyin()).yanitla('balık durumu nedir')).metin, isNot(contains('Balık Gölü')));
    // Gün adı mera sayılmaz
    expect((await (await _beyin()).yanitla('perşembe kartal nasıl')).spot?.name, 'Kartal');
    expect((await (await _beyin()).yanitla('pazar günü hava nasıl')).metin, isNot(contains('📍 Pazar')));
    expect((await (await _beyin()).yanitla('Pazar')).spot?.name, 'Pazar');
  });

  test('müşterinin surf seti isteği: uygun fiyatlı setler, bağlantılar, set oluştur', () async {
    final b = await _beyin();
    final y = await b.yanitla('müşteri akçakocada kıyıdan avlanıyor. drakion ve power force seti ona biraz pahalı geldi. '
        'daha uygun kıyıdan bir takım yapalım');
    expect(y.niyet, 'set_surf');
    expect(b.sonMera?.name, 'Akçakoca');
    expect(y.metin, contains('En uygun fiyatlı Surf setleri'));
    expect(y.metin, contains('product_id=61500'));
    expect(y.metin.indexOf('Captain'), lessThan(y.metin.indexOf('Oslo Crome')));
    expect(y.metin, contains('https://www.kiyidanav.com/set-olustur/'));
    expect(y.metin, contains('https://www.kiyidanav.com/olta-kamis-hazir-setler'));
    expect(y.metin, isNot(contains('Castira'))); // tek ürünlük kampanya set sayılmaz
    expect(y.metin, isNot(contains('Remixon'))); // stokta yok
    expect(y.metin, isNot(contains('Raketi')));
    expect(y.secenekler.first.eylem, KbEylem.urunAc);
    expect(y.secenekler.any((s) => s.eylem == KbEylem.sayfaAc && s.gonder == 'set-olustur/'), isTrue);
    expect(y.secenekler.any((s) => s.eylem == KbEylem.kategoriAc), isTrue);
  });

  test('bütçe, stilsiz istek, ekipman ve kampanya yanıtında setler', () async {
    expect(KiyidabiriBeyin.butce(kbNorm('5.000 TL')), 5000);
    expect(KiyidabiriBeyin.butce(kbNorm('5 bin lira')), 5000);
    expect(KiyidabiriBeyin.butce(kbNorm('420cm kamış')), isNull);
    final y = await (await _beyin()).yanitla('6000 TL surf seti');
    expect(y.metin, contains('6000 TL bütçeye uyan'));
    expect(y.metin, contains('Captain'));
    expect(y.metin, isNot(contains('Oslo Crome')));
    expect((await (await _beyin()).yanitla('2000 TL surf seti')).metin, contains('altında Surf seti şu an stokta yok'));
    final s = await (await _beyin()).yanitla('hazır set var mı');
    expect(s.niyet, 'set_sor');
    expect(s.secenekler.first.etiket, 'Surf seti');
    final e = await (await _beyin()).yanitla('Surf ekipmanı');
    expect(e.metin, contains('Surf için hazır setler'));
    expect(e.metin, contains('set-olustur'));
    final b = await _beyin();
    await b.yanitla('Surf ekipmanı');
    final k = await b.yanitla('kampanyalar');
    expect(k.metin, contains('Kampanya setleri'));
    expect(k.metin.indexOf('Captain'), lessThan(k.metin.indexOf('Oslo Zen Pro')));
  });

  test('set sayılmayan sorular', () {
    for (final q in ['mantarlı takım nasıl yapılır', 'hangi takımla avlanayım', 'siparişim olan set nerede', 'setur', 'kartal yarın nasıl']) {
      expect(KiyidabiriBeyin.setSorusu(kbNorm(q)), isFalse, reason: q);
    }
  });

  testWidgets('sohbetteki bağlantı tıklanır', (t) async {
    String? acilan;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: KbMetin('https://www.kiyidanav.com/set-olustur/', onBaglanti: (a) => acilan = a))));
    await t.tapAt(t.getTopLeft(find.byType(KbMetin)) + const Offset(20, 8));
    await t.pump(const Duration(milliseconds: 400));
    expect(acilan, 'https://www.kiyidanav.com/set-olustur/');
  });
}
