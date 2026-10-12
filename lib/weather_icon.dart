import 'package:flutter/material.dart';

/// Meteorolojik hava kodu (WMO, Open-Meteo "weather_code") → simge, Türkçe ad ve renk
class WeatherLook {
  final IconData icon;
  final String label;
  final Color color;
  const WeatherLook(this.icon, this.label, this.color);

  static const _sun = Color(0xFFFFD54F);
  static const _cloud = Color(0xFFD6E9E6);
  static const _rain = Color(0xFF4FC3F7);
  static const _storm = Color(0xFFFFB74D);
  static const _snow = Colors.white;

  static WeatherLook of(int? code) {
    switch (code) {
      case 0:
        return const WeatherLook(Icons.wb_sunny, 'Güneşli, açık', _sun);
      case 1:
        return const WeatherLook(Icons.wb_sunny_outlined, 'Az bulutlu', _sun);
      case 2:
        return const WeatherLook(Icons.filter_drama, 'Parçalı bulutlu', _cloud);
      case 3:
        return const WeatherLook(Icons.cloud, 'Kapalı, bulutlu', _cloud);
      case 45:
      case 48:
        return const WeatherLook(Icons.foggy, 'Sisli', _cloud);
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return const WeatherLook(Icons.grain, 'Çisenti', _rain);
      case 61:
        return const WeatherLook(Icons.water_drop_outlined, 'Hafif yağmurlu', _rain);
      case 63:
      case 66:
        return const WeatherLook(Icons.water_drop, 'Yağmurlu', _rain);
      case 65:
      case 67:
        return const WeatherLook(Icons.umbrella, 'Kuvvetli yağmur', _rain);
      case 71:
      case 73:
      case 75:
      case 77:
        return const WeatherLook(Icons.ac_unit, 'Karlı', _snow);
      case 80:
        return const WeatherLook(Icons.water_drop_outlined, 'Yer yer sağanak', _rain);
      case 81:
      case 82:
        return const WeatherLook(Icons.umbrella, 'Sağanak yağışlı', _rain);
      case 85:
      case 86:
        return const WeatherLook(Icons.ac_unit, 'Kar sağanağı', _snow);
      case 95:
        return const WeatherLook(Icons.thunderstorm, 'Gök gürültülü sağanak', _storm);
      case 96:
      case 99:
        return const WeatherLook(Icons.thunderstorm, 'Dolulu fırtına', _storm);
      default:
        return const WeatherLook(Icons.cloud_outlined, 'Hava bilgisi yok', _cloud);
    }
  }
}
