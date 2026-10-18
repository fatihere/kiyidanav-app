import 'package:flutter/material.dart';

import 'balik_rehberi.dart';
import 'bait_card.dart' show ayAdlari;
import 'kiyilama.dart';
import 'sea.dart';
import 'theme.dart';

/// "Kartal: Ekim ayında av veren balıklar" — bölgeye göre türler, yasal boy/limit, teknik ve bugünkü mesafe
class BolgeBaliklariKarti extends StatefulWidget {
  final Spot spot;
  final Kiyilama? kiyilama;
  const BolgeBaliklariKarti({super.key, required this.spot, this.kiyilama});

  @override
  State<BolgeBaliklariKarti> createState() => _BolgeBaliklariKartiState();
}

class _BolgeBaliklariKartiState extends State<BolgeBaliklariKarti> {
  static const _ilkGorunen = 4;
  bool _hepsi = false;

  @override
  void didUpdateWidget(BolgeBaliklariKarti old) {
    super.didUpdateWidget(old);
    if (old.spot.key != widget.spot.key) _hepsi = false;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bolge = balikBolgesi(widget.spot);
    final turler = bolgeTurleri(widget.spot, now);
    final gorunen = _hepsi ? turler : turler.take(_ilkGorunen).toList();
    final kalan = turler.length - _ilkGorunen;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E2D6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Tide.turuncu, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.set_meal, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.spot.name}: ${ayAdlari[now.month]} ayında av veren balıklar',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text('$bolge · av ihtimali en yüksek olandan başlayarak',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A60))),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < gorunen.length; i++) _satir(gorunen[i], i + 1, bolge, now),
        if (kalan > 0)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Tide.zeytinKoyu, alignment: Alignment.centerLeft),
            onPressed: () => setState(() => _hepsi = !_hepsi),
            icon: Icon(_hepsi ? Icons.expand_less : Icons.expand_more),
            label: Text(_hepsi ? 'Daralt' : 'Devamını göster ($kalan tür daha)'),
          ),
        const Divider(height: 18),
        const Text(
          'Amatör limit (6/2 Tebliğ): kiloyla sınırlı türlerde kişi başı toplam 5 kg; en büyük balık hariç tutulursa kalanı '
          'en çok 4 kg. Adet limitli türler birlikte en çok 3 adet. Boyu tutmayan balık yaralanmadan suya bırakılır. '
          'İl müdürlükleri ek yasak koyabilir.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B6A60), height: 1.35),
        ),
      ]),
    );
  }

  Widget _satir(String k, int sira, String bolge, DateTime now) {
    final b = baliklar[k]!;
    final yasak = b.yasakta(now);
    final p = avIhtimali(bolge, k, now);
    final ihtimal = yasak ? null : p >= 2.5 ? ('Yüksek', const Color(0xFF2E8B57)) : p >= 1.5 ? ('Orta', const Color(0xFFC98A1B)) : ('Düşük', const Color(0xFF8A8A80));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$sira. ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Tide.turuncu)),
          Expanded(child: Text(b.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
          if (yasak)
            const _Etiket('AV YASAĞI', Tide.mercan)
          else
            _Etiket('İHTİMAL: ${ihtimal!.$1.toUpperCase()}', ihtimal.$2),
        ]),
        const SizedBox(height: 2),
        Text('Asgari boy: ${b.boy} · Limit: ${b.limit} · Kıyıdan ${b.mesafeMin}–${b.mesafeMax} m'
            '${b.yasak != null ? ' · Yasak: ${b.yasakMetni}' : ''}'
            '${b.sezonda(now.month) ? '' : ' · şu an sezon dışı'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF55554B))),
        Text(b.teknik, style: const TextStyle(fontSize: 12.5)),
        if (b.not.isNotEmpty) Text(b.not, style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A1A))),
      ]),
    );
  }
}

class _Etiket extends StatelessWidget {
  final String t;
  final Color c;
  const _Etiket(this.t, this.c);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
      );
}
