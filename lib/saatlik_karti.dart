import 'package:flutter/material.dart';

import 'saatlik_skor.dart';
import 'sea.dart';
import 'theme.dart';

/// 1.17.0: Mera Bilgisi › saatlik av skoru şeridi (bugün / yarın / öbür gün), en iyi 2 pencere ve
/// o gün en olası 3 tür. Hesap saatlik_skor.dart'ta; Kıyıdabiri de aynı hesabı söyler.
class SaatlikSkorKarti extends StatefulWidget {
  final SpotForecast f;
  final DateTime? simdi;
  const SaatlikSkorKarti({super.key, required this.f, this.simdi});

  @override
  State<SaatlikSkorKarti> createState() => _SaatlikSkorKartiState();
}

class _SaatlikSkorKartiState extends State<SaatlikSkorKarti> {
  int _gun = 0;
  int? _secili; // seçilen çubuğun sırası
  late List<SaatSkoru> _hepsi = SaatlikSkor.hepsi(widget.f);

  @override
  void didUpdateWidget(covariant SaatlikSkorKarti old) {
    super.didUpdateWidget(old);
    if (!identical(old.f, widget.f)) {
      _hepsi = SaatlikSkor.hepsi(widget.f);
      _secili = null;
    }
  }

  static Color renk(int s) {
    if (s >= 80) return Tide.yosun;
    if (s >= 65) return const Color(0xFF8DB43C);
    if (s >= 50) return Tide.altin;
    if (s >= 35) return Tide.turuncu;
    return Tide.misina;
  }

  @override
  Widget build(BuildContext context) {
    final simdi = widget.simdi ?? DateTime.now();
    if (_hepsi.isEmpty) return const SizedBox.shrink();
    final gunler = [for (var g = 0; g < 3; g++) if (SaatlikSkor.gun(_hepsi, g, simdi: simdi).length >= 3) g];
    if (gunler.isEmpty) return const SizedBox.shrink();
    if (!gunler.contains(_gun)) _gun = gunler.first;
    final saatler = SaatlikSkor.gun(_hepsi, _gun, simdi: simdi);
    final pencereler = SaatlikSkor.enIyiPencereler(saatler);
    final turler = turSkorlari(widget.f.spot, saatler);
    bool pencerede(SaatSkoru s) => pencereler.any((p) => !s.time.isBefore(p.bas) && s.time.isBefore(p.bit));
    final sec = _secili != null && _secili! < saatler.length ? saatler[_secili!] : null;
    const gunAd = ['Bugün', 'Yarın', 'Öbür gün'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.schedule, color: Tide.zeytinKoyu, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Saatlik av skoru',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Tide.zeytinKoyu)),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final g in gunler)
                ChoiceChip(
                  label: Text(gunAd[g], style: const TextStyle(fontSize: 12)),
                  selected: _gun == g,
                  visualDensity: VisualDensity.compact,
                  selectedColor: Tide.somon,
                  onSelected: (_) => setState(() {
                    _gun = g;
                    _secili = null;
                  }),
                ),
            ]),
            if (pencereler.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'En iyi saatler: ', style: TextStyle(color: Tide.kaya)),
                  for (var i = 0; i < pencereler.length; i++) ...[
                    if (i > 0) const TextSpan(text: '  ·  '),
                    TextSpan(
                        text: '${pencereler[i].metin} %${pencereler[i].skor}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.turuncu)),
                  ],
                ])),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: saatler.length,
                itemBuilder: (_, i) {
                  final s = saatler[i];
                  final vurgu = pencerede(s);
                  final secili = _secili == i;
                  return GestureDetector(
                    onTap: () => setState(() => _secili = secili ? null : i),
                    child: Container(
                      width: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${s.skor}',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: vurgu || secili ? FontWeight.w800 : FontWeight.w500,
                                color: vurgu ? Tide.turuncu : Tide.kaya)),
                        const SizedBox(height: 2),
                        Container(
                          height: 70.0 * s.skor / 100,
                          decoration: BoxDecoration(
                            color: renk(s.skor),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: secili ? Tide.derin : (vurgu ? Tide.turuncu : Colors.transparent), width: 2),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 14,
                          child: Text(
                            s.solunar == 2 ? '◆' : s.solunar == 1 ? '◇' : (s.time.hour % 3 == 0 ? '${s.time.hour}' : ''),
                            style: TextStyle(
                                fontSize: 10, color: s.solunar > 0 ? Tide.derinAcik : Tide.misina, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            if (sec != null)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Tide.zemin, borderRadius: BorderRadius.circular(10)),
                child: Text(_ayrinti(sec), style: const TextStyle(fontSize: 12.5, color: Tide.kaya)),
              ),
            if (turler.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${gunAd[_gun]} en olası türler',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.zeytinKoyu, fontSize: 14)),
              const SizedBox(height: 6),
              for (final t in turler)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(
                        width: 96,
                        child: Text(t.ad,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: t.skor / 100,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEDEBE2),
                          color: renk(t.skor),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 136,
                        child: Text('  %${t.skor} · ${t.pencere?.metin ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  ]),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              'Çubuğa dokun: o saatin ayrıntısı. ◆ büyük, ◇ küçük solunar dönem (yaklaşık). '
              'Saatlik skor tahminidir${SkorAyar.ornek > 0 ? '; ${SkorAyar.ornek} av kaydıyla ayarlandı' : ''}.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF77766A)),
            ),
          ]),
        ),
      ),
    );
  }

  static String _ayrinti(SaatSkoru s) {
    final h = s.h;
    final p = <String>[
      '${s.time.hour.toString().padLeft(2, '0')}:00 · %${s.skor} · ${s.dilim.ad}',
      if (h.effectiveWind != null) 'rüzgâr ${h.effectiveWind!.round()} km/s',
      if (h.waveM != null) 'dalga ${h.waveM!.toStringAsFixed(1)} m',
      if (h.seaC != null) 'su ${h.seaC!.round()}°',
      if ((h.rainMm ?? 0) >= 0.2) 'yağış ${h.rainMm!.toStringAsFixed(1)} mm',
      if (s.solunar == 2) 'solunar büyük dönem' else if (s.solunar == 1) 'solunar küçük dönem',
    ];
    return p.join(' · ');
  }
}
