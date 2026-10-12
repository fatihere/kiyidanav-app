import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sea.dart';
import 'solunar.dart';

/// Android ana ekran kartı ("Mera Bilgisi" widget'ı): seçili meranın günlük av verimliliği.
/// Kartın görünümü yerel Android kodudur (tool/android/widget); veriyi buradan yazarız.
class MeraWidget {
  static const _provider = 'MeraWidgetProvider';
  static const _qualified = 'com.kiyidanav.kiyidanav.MeraWidgetProvider';

  /// Panelden açık/kapalı bilgisi ve üyelik (arka planda da okunabilsin diye saklanır)
  static const _onKey = 'widget_acik';
  static const _updatedKey = 'widget_guncelleme';

  /// Kart ekranda var mı? (yerel kod kart eklenince/kaldırılınca yazar)
  static const _placedKey = 'widget_var';

  static bool get _supported => Platform.isAndroid;

  /// Uygulama açılışında: panel ayarı ve üyelik durumuna göre kartı hazırlar
  static Future<void> syncAccess({required bool enabled, required bool member}) async {
    if (!_supported) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_onKey, enabled);
      if (!enabled) {
        await _write(
          ad: 'KıyıdanAv',
          skor: '—',
          etiket: '',
          ozet: 'Ana ekran kartı şu an kapalı.',
          balik: '',
          saat: '',
          puan: -1,
        );
      } else if (!member) {
        await _write(
          ad: 'Mera Bilgisi',
          skor: '%?',
          etiket: 'Üyelere özel',
          ozet: 'Ücretsiz üye girişi yap; seçtiğin meranın av verimliliği burada görünsün.',
          balik: '',
          saat: 'Dokun ve giriş yap',
          puan: -1,
        );
      }
    } catch (e) {
      debugPrint('ana ekran kartı: $e');
    }
  }

  /// Mera Bilgisi ekranı hesapladığında (en doğru puan: üye avları ve uydu verisi dahil)
  static Future<void> fromReport(SpotForecast f, int score) async {
    if (!_supported) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_onKey) ?? true) || !(p.getBool('member_v1') ?? false)) return;
      await _fromForecast(f, score);
      await p.setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('ana ekran kartı: $e');
    }
  }

  /// Arka planda (15 dakikalık görev): kart ekrandaysa ve veri 1 saatten eskiyse yeniler
  static Future<void> refreshIfStale() async {
    if (!_supported) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_onKey) ?? true) || !(p.getBool('member_v1') ?? false)) return;
      final placed = await HomeWidget.getWidgetData<bool>(_placedKey, defaultValue: false);
      if (placed != true) return;
      final last = p.getInt(_updatedKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last < const Duration(minutes: 55).inMilliseconds) return;
      final name = p.getString('spot_v2');
      final match = spots.where((s) => s.name == name);
      final spot = match.isNotEmpty ? match.first : spots[5];
      final f = await SeaService.fetchWeek(spot);
      final score = FishingScore.compute(DateTime.now(),
          windKmh: f.now.effectiveWind,
          waveM: f.now.effectiveWave,
          pressureTrend: f.pressureTrend,
          rainMm: f.now.rainDay,
          currentKmh: f.now.currentKmh);
      await _fromForecast(f, score);
      await p.setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('ana ekran kartı arka plan: $e');
    }
  }

  static Future<void> _fromForecast(SpotForecast f, int score) async {
    final r = f.now;
    final parts = <String>[
      'Rüzgâr ${r.windKmh?.round() ?? '-'} km/s${r.windFrom.isEmpty ? '' : ' ${r.windFrom}'}',
      if (r.strait) '${f.spot.shelter} içi' else if (r.waveM != null) 'Dalga ${r.effectiveWave.toStringAsFixed(1)} m',
      if (r.seaC != null) 'Su ${r.seaC!.round()}°',
    ];
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    await _write(
      ad: '${f.spot.name} · ${f.spot.side.label}',
      skor: '%$score',
      etiket: FishingScore.label(score),
      ozet: '${parts.join(' · ')}\n${r.verdict}',
      balik: '🐟' * FishingScore.fishCount(score),
      saat: '${Moon.phaseName(now)} · ${two(now.hour)}:${two(now.minute)} güncellendi',
      puan: score,
    );
  }

  static Future<void> _write({
    required String ad,
    required String skor,
    required String etiket,
    required String ozet,
    required String balik,
    required String saat,
    required int puan,
  }) async {
    await HomeWidget.saveWidgetData<String>('mera_ad', ad);
    await HomeWidget.saveWidgetData<String>('mera_skor', skor);
    await HomeWidget.saveWidgetData<String>('mera_etiket', etiket);
    await HomeWidget.saveWidgetData<String>('mera_ozet', ozet);
    await HomeWidget.saveWidgetData<String>('mera_balik', balik);
    await HomeWidget.saveWidgetData<String>('mera_saat', saat);
    await HomeWidget.saveWidgetData<String>('mera_puan', '$puan');
    await HomeWidget.updateWidget(name: _provider, androidName: _provider, qualifiedAndroidName: _qualified);
  }

  /// Karta dokunularak açıldıysa true (Mera Bilgisi sekmesine geçilir)
  static bool isWidgetLink(Uri? u) => u != null && u.scheme == 'kiyidanav' && u.host == 'mera';
}
