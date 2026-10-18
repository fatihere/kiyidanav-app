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
  bool _sezonDisi = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final turler = bolgeTurleri(widget.spot);
    final sezonda = turler.where((k) => baliklar[k]!.sezonda(now.month)).toList();
    final disi = turler.where((k) => !baliklar[k]!.sezonda(now.month)).toList();
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
              Text('${balikBolgesi(widget.spot)} · ${sezonda.length} tür sezonda',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B6A60))),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        for (final k in sezonda) _satir(k, now),
        if (disi.isNotEmpty) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Tide.zeytinKoyu, alignment: Alignment.centerLeft),
            onPressed: () => setState(() => _sezonDisi = !_sezonDisi),
            child: Text('${_sezonDisi ? 'Gizle' : 'Göster'}: sezon dışı ${disi.length} tür'),
          ),
          if (_sezonDisi) for (final k in disi) _satir(k, now),
        ],
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

  Widget _satir(String k, DateTime now) {
    final b = baliklar[k]!;
    final kl = widget.kiyilama;
    final menzil = kl != null &&
        ((b.mesafeMin <= kl.kucukMax && b.mesafeMax >= kl.kucukMin) || (b.mesafeMin <= kl.buyukMax && b.mesafeMax >= kl.buyukMin));
    final yasak = b.yasakta(now);
    final yeni = herBolge.contains(k);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: b.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              if (yeni)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: _Etiket('YENİ', Color(0xFF2F8F86)),
                  ),
                ),
            ])),
          ),
          if (yasak)
            const _Etiket('AV YASAĞI', Tide.mercan)
          else if (menzil)
            const _Etiket('BUGÜN MENZİLDE', Color(0xFF2E8B57)),
        ]),
        const SizedBox(height: 2),
        Text('Asgari boy: ${b.boy} · Limit: ${b.limit} · Kıyıdan ${b.mesafeMin}–${b.mesafeMax} m'
            '${b.yasak != null ? ' · Yasak: ${b.yasakMetni}' : ''}',
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
