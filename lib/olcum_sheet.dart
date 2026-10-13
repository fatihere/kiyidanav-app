import 'package:flutter/material.dart';

import 'olcum_yorum.dart';
import 'overlays.dart';
import 'theme.dart';

Color tonRengi(Ton t) {
  switch (t) {
    case Ton.iyi:
      return const Color(0xFF2E8B57);
    case Ton.orta:
      return const Color(0xFFC98A1B);
    case Ton.zayif:
      return const Color(0xFFB0413E);
  }
}

/// Mera kartındaki bir ölçüme dokununca açılan açıklama
void showOlcumSheet(BuildContext context, OlcumYorum y) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tide.derin,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(y.baslik, style: const TextStyle(color: Color(0xFF9FC4BD), fontSize: 13)),
                  Text(y.deger,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
              CloseX(onTap: () => Navigator.of(ctx).pop(), color: Colors.white, background: const Color(0x33FFFFFF)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: tonRengi(y.ton), borderRadius: BorderRadius.circular(10)),
              child: Text(y.durum,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (y.mesafe.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.straighten, color: Tide.turuncu, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(y.mesafe,
                      style: const TextStyle(color: Color(0xFFFFE0CC), fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.35)),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            for (final m in y.maddeler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: Color(0xFFFFD54F)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
                ]),
              ),
            if (y.kurallar.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('NASIL OKUNUR',
                  style: TextStyle(color: Color(0xFFCFE3E0), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (var i = 0; i < y.kurallar.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: i == y.aktif ? const Color(0x33F46C22) : const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == y.aktif ? Tide.turuncu : Colors.transparent),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i == y.aktif ? '${y.kurallar[i].$1}  ← şu an' : y.kurallar[i].$1,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(y.kurallar[i].$2,
                        style: const TextStyle(color: Color(0xFFD6E9E6), fontSize: 12.5, height: 1.35)),
                  ]),
                ),
            ],
            if (y.not.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(y.not, style: const TextStyle(color: Color(0xFF8FB0AA), fontSize: 11.5, height: 1.35)),
            ],
          ]),
        ),
      ),
    ),
  );
}
