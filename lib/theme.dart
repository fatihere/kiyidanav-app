import 'package:flutter/material.dart';

/// kiyidanav.com renkleriyle uyumlu tema.
/// Zeytin menü, turuncu eylem düğmesi, somon arama kutusu, altın sepet — sitedeki gibi.
class Tide {
  // Site renkleri
  static const zeytin = Color(0xFF6F6B45); // üst menü şeridi
  static const zeytinKoyu = Color(0xFF4A4730); // başlık, koyu vurgu
  static const turuncu = Color(0xFFF46C22); // sitenin "Sepete ekle" turuncusu
  static const somon = Color(0xFFF9C7B1); // sitenin arama kutusu
  static const altin = Color(0xFFD6AE3A); // sitenin sepet kutusu
  static const zemin = Color(0xFFF6F4EE); // sıcak kırık beyaz

  // Deniz kartı (imza anı) için derin su tonları
  static const derin = Color(0xFF0E3B43);
  static const derinAcik = Color(0xFF1C5A63);

  // Yardımcılar
  static const kaya = Color(0xFF26261E); // metin
  static const misina = Color(0xFFA7A58E); // pasif
  static const yosun = Color(0xFF3F8F4B); // stokta
  static const mercan = Color(0xFFD0342C); // indirim, uyarı

  // Eski adlarla uyumluluk
  static const samandira = turuncu;
  static const kopuk = zemin;

  static const font = 'Armata';

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(seedColor: zeytin).copyWith(
      primary: zeytinKoyu,
      onPrimary: Colors.white,
      secondary: turuncu,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: kaya,
      error: mercan,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: scheme,
      scaffoldBackgroundColor: zemin,
      appBarTheme: const AppBarTheme(
        backgroundColor: zemin,
        foregroundColor: kaya,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: font, color: kaya, fontSize: 19, fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: kaya),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: kaya),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kaya),
        bodyLarge: TextStyle(fontSize: 15.5, height: 1.5, color: kaya),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: kaya),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
