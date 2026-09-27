import 'package:flutter/material.dart';

/// "Tide" tasarım dili — kıyıdan balıkçılığın renkleri.
class Tide {
  static const derin = Color(0xFF0E3B43); // derin su
  static const derinAcik = Color(0xFF1C5A63);
  static const kopuk = Color(0xFFEEF3F1); // dalga köpüğü (zemin)
  static const samandira = Color(0xFFF2672E); // şamandıra turuncusu (eylem)
  static const misina = Color(0xFF9DB8B2); // yardımcı, pasif
  static const kaya = Color(0xFF22292C); // metin
  static const yosun = Color(0xFF3F8F6B); // stokta / olumlu
  static const mercan = Color(0xFFC0392B); // indirim / uyarı

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: derin,
      brightness: Brightness.light,
    ).copyWith(
      primary: derin,
      onPrimary: Colors.white,
      secondary: samandira,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: kaya,
      error: mercan,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: kopuk,
      appBarTheme: const AppBarTheme(
        backgroundColor: kopuk,
        foregroundColor: kaya,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: kaya,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: kaya),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: kaya),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: kaya),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: kaya),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: kaya),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
