import 'package:flutter/material.dart';

import 'theme.dart';

/// Yönetim panelinden (Mobil Uygulama → Görünüm) değiştirilebilen renk ve boyutlar.
/// Panelde bir alan boş bırakılırsa buradaki varsayılan kullanılır; uygulamayı yeniden
/// derlemeye gerek kalmaz, değişiklik bir sonraki açılışta (veya yenilemede) gelir.
class Ui {
  // Ana renkler
  final Color vurgu; // turuncu eylem rengi
  final Color zemin; // sayfa arka planı
  final Color menuZemin; // üst kategori şeridi
  final Color menuYazi;
  final double menuYaziBoyut;

  // "Hangi ay hangi balık" kartı
  final Color yemBaslikZemin;
  final Color yemBaslikYazi;
  final Color yemCerceve;
  final Color yemAyirici;
  final Color yemBalikYazi;
  final double yemBaslikBoyut;
  final double yemBalikBoyut;
  final double yemMetinBoyut;

  // Ana sayfa bölümleri (Hazır Olta Setleri, LRF Ekipmanları…)
  final Color bolumZemin;
  final Color bolumCerceve;
  final Color bolumBaslikZemin;
  final Color bolumBaslikYazi;
  final Color bolumBaslikCizgi; // başlığın solundaki vurgu çizgisi
  final double bolumBaslikBoyut;
  final double bolumKose;
  final double bolumAralik;

  // Ürün kartı
  final double urunAdBoyut;
  final double urunFiyatBoyut;

  // Mera Bilgisi
  final bool meraDinamikZemin; // hava/deniz durumuna göre arka plan
  final bool meraSesAcik; // ortam sesi açılışta açık mı
  final double meraSesSeviye; // 0..1

  const Ui({
    this.vurgu = Tide.turuncu,
    this.zemin = Tide.zemin,
    this.menuZemin = Tide.zeytin,
    this.menuYazi = Colors.white,
    this.menuYaziBoyut = 13,
    this.yemBaslikZemin = Tide.turuncu,
    this.yemBaslikYazi = Colors.white,
    this.yemCerceve = const Color(0xFFF3C9AE),
    this.yemAyirici = const Color(0xFFF7DCCB),
    this.yemBalikYazi = Tide.zeytinKoyu,
    this.yemBaslikBoyut = 16,
    this.yemBalikBoyut = 16,
    this.yemMetinBoyut = 13,
    this.bolumZemin = Colors.white,
    this.bolumCerceve = const Color(0xFFE6E2D6),
    this.bolumBaslikZemin = const Color(0xFFF4F1E6),
    this.bolumBaslikYazi = Tide.zeytinKoyu,
    this.bolumBaslikCizgi = Tide.turuncu,
    this.bolumBaslikBoyut = 17,
    this.bolumKose = 18,
    this.bolumAralik = 16,
    this.urunAdBoyut = 13.5,
    this.urunFiyatBoyut = 16,
    this.meraDinamikZemin = true,
    this.meraSesAcik = false,
    this.meraSesSeviye = 0.6,
  });

  static Color? _c(dynamic v) {
    if (v is! String) return null;
    var s = v.trim().replaceFirst('#', '');
    if (s.length == 3) s = s.split('').map((e) => '$e$e').join();
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final n = int.tryParse(s, radix: 16);
    return n == null ? null : Color(n);
  }

  static double? _d(dynamic v, double min, double max) {
    final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));
    if (d == null || d.isNaN) return null;
    return d.clamp(min, max).toDouble();
  }

  static bool? _b(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String && v.isNotEmpty) return v == '1' || v == 'true' || v == 'evet';
    return null;
  }

  factory Ui.fromJson(Map<String, dynamic>? j) {
    const d = Ui();
    if (j == null) return d;
    return Ui(
      vurgu: _c(j['vurgu']) ?? d.vurgu,
      zemin: _c(j['zemin']) ?? d.zemin,
      menuZemin: _c(j['menu_zemin']) ?? d.menuZemin,
      menuYazi: _c(j['menu_yazi']) ?? d.menuYazi,
      menuYaziBoyut: _d(j['menu_yazi_boyut'], 10, 20) ?? d.menuYaziBoyut,
      yemBaslikZemin: _c(j['yem_baslik_zemin']) ?? d.yemBaslikZemin,
      yemBaslikYazi: _c(j['yem_baslik_yazi']) ?? d.yemBaslikYazi,
      yemCerceve: _c(j['yem_cerceve']) ?? d.yemCerceve,
      yemAyirici: _c(j['yem_ayirici']) ?? d.yemAyirici,
      yemBalikYazi: _c(j['yem_balik_yazi']) ?? d.yemBalikYazi,
      yemBaslikBoyut: _d(j['yem_baslik_boyut'], 12, 26) ?? d.yemBaslikBoyut,
      yemBalikBoyut: _d(j['yem_balik_boyut'], 12, 24) ?? d.yemBalikBoyut,
      yemMetinBoyut: _d(j['yem_metin_boyut'], 10, 20) ?? d.yemMetinBoyut,
      bolumZemin: _c(j['bolum_zemin']) ?? d.bolumZemin,
      bolumCerceve: _c(j['bolum_cerceve']) ?? d.bolumCerceve,
      bolumBaslikZemin: _c(j['bolum_baslik_zemin']) ?? d.bolumBaslikZemin,
      bolumBaslikYazi: _c(j['bolum_baslik_yazi']) ?? d.bolumBaslikYazi,
      bolumBaslikCizgi: _c(j['bolum_baslik_cizgi']) ?? d.bolumBaslikCizgi,
      bolumBaslikBoyut: _d(j['bolum_baslik_boyut'], 12, 28) ?? d.bolumBaslikBoyut,
      bolumKose: _d(j['bolum_kose'], 0, 32) ?? d.bolumKose,
      bolumAralik: _d(j['bolum_aralik'], 0, 40) ?? d.bolumAralik,
      urunAdBoyut: _d(j['urun_ad_boyut'], 10, 20) ?? d.urunAdBoyut,
      urunFiyatBoyut: _d(j['urun_fiyat_boyut'], 11, 24) ?? d.urunFiyatBoyut,
      meraDinamikZemin: _b(j['mera_dinamik_zemin']) ?? d.meraDinamikZemin,
      meraSesAcik: _b(j['mera_ses_acik']) ?? d.meraSesAcik,
      meraSesSeviye: _d(j['mera_ses_seviye'], 0, 1) ?? d.meraSesSeviye,
    );
  }
}
