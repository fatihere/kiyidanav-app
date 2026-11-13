import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notices.dart';
import 'sea.dart';
import 'theme.dart';

/// 1.17.1: hava değişimi uyarıları (önümüzdeki saatler, uygulamanın saatlik tahmininden).
/// Mera Bilgisi'nde kart, Kıyıdabiri'nde satır ve arka planda yerel bildirim olarak gösterilir.
/// Yalnız kötüleşme uyarılır: rüzgârın sertleşmesi / fırtına, dalganın büyümesi, yağış, basıncın hızla düşmesi,
/// sert rüzgârda yön dönmesi.
class HavaUyari {
  final String tur; // ruzgar | firtina | dalga | yagis | basinc | yon
  final String baslik;
  final String metin;
  final DateTime zaman;
  final int seviye; // 1 dikkat, 2 tehlike
  const HavaUyari(this.tur, this.baslik, this.metin, this.zaman, this.seviye);

  static const _yonler = ['Yıldız', 'Poyraz', 'Gündoğusu', 'Keşişleme', 'Kıble', 'Lodos', 'Günbatısı', 'Karayel'];
  static String yonAdi(int? d) => d == null ? '' : _yonler[((d % 360) / 45).round() % 8];
  static String _hh(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

  /// Önümüzdeki [saat] saatteki uyarılar (en erken başlayan başta)
  static List<HavaUyari> hesapla(SpotForecast f, {int saat = 24}) {
    final h = f.hours;
    if (h.length < 3) return const [];
    final simdi = h.first;
    final pencere = h.take(saat).toList();
    final out = <HavaUyari>[];
    final w0 = simdi.effectiveWind ?? 0;

    // Fırtına (hamle) önce; varsa ayrıca "rüzgâr sertleşiyor" denmez
    final firtina = pencere.where((x) => (x.gustKmh ?? 0) >= 55).firstOrNull;
    if (firtina != null && (simdi.gustKmh ?? 0) < 55) {
      out.add(HavaUyari('firtina', 'Fırtına uyarısı', '${_hh(firtina.time)} civarı hamleler ${firtina.gustKmh!.round()} km/s '
          '${yonAdi(firtina.windDir)}. Kıyıda, mendirek ve kayalıkta durma; takımını erken topla.', firtina.time, 2));
    } else {
      final sert = pencere.where((x) => (x.effectiveWind ?? 0) >= 30 && (x.effectiveWind ?? 0) >= w0 + 12).firstOrNull;
      if (sert != null) {
        final enCok = pencere.map((x) => x.effectiveWind ?? 0).reduce((a, b) => a > b ? a : b);
        out.add(HavaUyari('ruzgar', 'Rüzgâr sertleşiyor', '${_hh(sert.time)}\'ten sonra ${yonAdi(sert.windDir)} ${sert.effectiveWind!.round()} km/s '
            '(şu an ${w0.round()}, en çok ${enCok.round()} km/s). Ağır takım ve korunaklı kıyı seç.', sert.time, enCok >= 45 ? 2 : 1));
      }
    }
    // Dalga
    final v0 = simdi.waveM ?? 0;
    final dalga = pencere.where((x) => (x.waveM ?? 0) >= 1.2 && (x.waveM ?? 0) >= v0 + 0.5).firstOrNull;
    if (dalga != null) {
      final enCok = pencere.map((x) => x.waveM ?? 0).reduce((a, b) => a > b ? a : b);
      out.add(HavaUyari('dalga', 'Dalga büyüyor', '${_hh(dalga.time)}\'ten sonra dalga ${dalga.waveM!.toStringAsFixed(1)} m '
          '(şu an ${v0.toStringAsFixed(1)} m, en çok ${enCok.toStringAsFixed(1)} m). Mendirek ve kaya üstünde dikkat.', dalga.time, enCok >= 2 ? 2 : 1));
    }
    // Yağış
    if ((simdi.rainMm ?? 0) < 0.5) {
      final yagis = pencere.where((x) => (x.rainMm ?? 0) >= 2).firstOrNull;
      if (yagis != null) {
        final enCok = pencere.map((x) => x.rainMm ?? 0).reduce((a, b) => a > b ? a : b);
        out.add(HavaUyari('yagis', enCok >= 8 ? 'Sağanak geliyor' : 'Yağış başlıyor',
            '${_hh(yagis.time)} civarı yağış (saatte ${enCok.toStringAsFixed(1)} mm\'ye kadar).${enCok >= 8 ? ' Şimşekte karbon kamışla açıkta durma.' : ''}',
            yagis.time, enCok >= 8 ? 2 : 1));
      }
    }
    // Basınç: 12 saatte 4 hPa ve üzeri düşüş
    final p0 = simdi.pressure;
    if (p0 != null && pencere.length > 12) {
      final p12 = pencere[12].pressure;
      if (p12 != null && p0 - p12 >= 4) {
        out.add(HavaUyari('basinc', 'Basınç hızla düşüyor', '12 saatte ${(p0 - p12).toStringAsFixed(0)} hPa düşüş: hava bozabilir, '
            'rüzgâr ve dalga artabilir.', pencere[12].time, 1));
      }
    }
    // Sert rüzgârda yön dönmesi (ör. Poyraz'dan Lodos'a)
    final d0 = simdi.windDir;
    if (d0 != null) {
      for (final x in pencere.take(12)) {
        final d = x.windDir;
        if (d == null || (x.effectiveWind ?? 0) < 20) continue;
        final fark = ((d - d0) % 360 + 360) % 360;
        final aci = fark > 180 ? 360 - fark : fark;
        if (aci >= 90 && yonAdi(d) != yonAdi(d0)) {
          out.add(HavaUyari('yon', 'Rüzgâr yön değiştiriyor', '${_hh(x.time)} civarı ${yonAdi(d0)}\'dan ${yonAdi(d)}\'a dönüyor '
              '(${x.effectiveWind!.round()} km/s). Kıyının durumu değişebilir; atış yönünü ve güvenliği yeniden değerlendir.', x.time, 1));
          break;
        }
      }
    }
    out.sort((a, b) => a.zaman.compareTo(b.zaman));
    return out;
  }

  /// Kıyıdabiri için tek satır
  static String ozet(SpotForecast f) {
    final l = hesapla(f);
    if (l.isEmpty) return '';
    return '⚠️ ${l.map((u) => '${u.baslik}: ${u.metin}').join(' ')}\n';
  }

  // ------------------------------------------------------------------ arka plan bildirimi
  static const _key = 'hava_uyari_bildirildi_v1';

  /// Seçili mera için önümüzdeki 12 saatte yeni bir uyarı varsa yerel bildirim (her tür günde bir kez)
  static Future<void> arkaPlanKontrol() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('hava_uyari_kapali') ?? false) return;
      final spot = spotFromKey(p.getString('spot_v2'));
      final f = await SeaService.fetchWeek(spot);
      final l = hesapla(f, saat: 12);
      if (l.isEmpty) return;
      final eski = Map<String, dynamic>.from(jsonDecode(p.getString(_key) ?? '{}') as Map);
      for (final u in l) {
        final k = '${spot.key}|${u.tur}|${u.zaman.toIso8601String().substring(0, 10)}';
        if (eski.containsKey(k)) continue;
        eski[k] = DateTime.now().toIso8601String();
        await Notices.yerelGoster(Notice(
          id: 'hava-$k',
          type: 'rapor',
          title: '⚠️ ${spot.name}: ${u.baslik}',
          body: u.metin,
          image: '',
          target: '',
          date: DateTime.now().toIso8601String(),
        ));
      }
      final sinir = DateTime.now().subtract(const Duration(days: 5));
      eski.removeWhere((_, v) => (DateTime.tryParse('$v') ?? DateTime(2000)).isBefore(sinir));
      await p.setString(_key, jsonEncode(eski));
    } catch (e) {
      debugPrint('hava uyarısı arka plan: $e');
    }
  }
}

/// Mera Bilgisi › hava değişimi uyarı kartı (uyarı yoksa görünmez)
class HavaUyariKarti extends StatelessWidget {
  final SpotForecast f;
  const HavaUyariKarti({super.key, required this.f});

  @override
  Widget build(BuildContext context) {
    final l = HavaUyari.hesapla(f);
    if (l.isEmpty) return const SizedBox.shrink();
    final tehlike = l.any((u) => u.seviye >= 2);
    final renk = tehlike ? Tide.mercan : const Color(0xFFE08A00);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: renk, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(tehlike ? Icons.warning_amber_rounded : Icons.info_outline, color: renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tehlike ? 'Hava değişiyor — dikkat!' : 'Hava değişiyor',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: renk)),
            ),
          ]),
          for (final u in l) ...[
            const SizedBox(height: 8),
            Text(u.baslik, style: const TextStyle(fontWeight: FontWeight.w800, color: Tide.kaya)),
            Text(u.metin, style: const TextStyle(fontSize: 13.5, color: Tide.kaya, height: 1.3)),
          ],
        ]),
      ),
    );
  }
}
