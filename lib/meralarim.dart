import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'locate.dart';
import 'sea.dart';

/// 1.13.2 — Meralarım: haritada listede olmayan bir yere iğne bırakıldığında o noktanın gerçek adı
/// (ör. "Anadolu Kavağı") öğrenilir, yeni mera olarak telefondaki kütüphaneye eklenir, haritada
/// işaretlenir ve listede "Meralarım" başlığında önerilir. Tahminler o noktanın kendi koordinatından alınır.
class Meralarim {
  static const _key = 'meralarim_v1';
  static const _enFazla = 40;
  static final liste = ValueNotifier<List<Spot>>(const []);

  static Future<void> yukle() async {
    try {
      final l = (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
      liste.value = l.map(spotFromKey).where((s) => s.ogrenilmis).toList();
    } catch (_) {}
  }

  static Future<void> _kaydet() async {
    try {
      (await SharedPreferences.getInstance()).setStringList(_key, liste.value.map(spotToKey).toList());
    } catch (_) {}
  }

  /// Aynı yere (~400 m) daha önce eklenmiş mera varsa onu döndürür
  static Spot? yakinda(double lat, double lon) {
    for (final s in liste.value) {
      if (Locate.km(lat, lon, s.lat, s.lon) < 0.4) return s;
    }
    return null;
  }

  /// Öğrenilen merayı kütüphaneye ekler (en yeni başta); aynı yerdeki eski kayıt güncellenir
  static Future<Spot> ekle(Spot s) async {
    if (!s.ogrenilmis) return s;
    final l = [s, ...liste.value.where((e) => Locate.km(e.lat, e.lon, s.lat, s.lon) >= 0.4)];
    liste.value = l.take(_enFazla).toList();
    await _kaydet();
    return s;
  }

  static Future<void> sil(Spot s) async {
    liste.value = liste.value.where((e) => spotToKey(e) != spotToKey(s)).toList();
    await _kaydet();
  }

  // ------------------------------------------------------------ yer adı (OpenStreetMap)
  static final Map<String, (String, Side?)> _onbellek = {};
  static const _anadolu = {
    'adalar', 'ataşehir', 'beykoz', 'çekmeköy', 'kadıköy', 'kartal', 'maltepe', 'pendik', 'sancaktepe',
    'sultanbeyli', 'şile', 'tuzla', 'ümraniye', 'üsküdar'
  };

  /// İğnenin altındaki yerin adı ("Anadolu Kavağı, Beykoz") ve İstanbul'da hangi yakada olduğu.
  /// Ağ yoksa / bulunamazsa null.
  static Future<(String, Side?)?> yerAdi(double lat, double lon) async {
    final k = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
    final o = _onbellek[k];
    if (o != null) return o;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toStringAsFixed(5),
        'lon': lon.toStringAsFixed(5),
        'zoom': '16',
        'addressdetails': '1',
        'accept-language': 'tr',
      });
      final r = await http.get(uri, headers: const {
        'User-Agent': 'KiyidanAv/1.13.2 (https://www.kiyidanav.com)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      if (j is! Map || j['address'] is! Map) return null;
      final a = Map<String, dynamic>.from(j['address'] as Map);
      String al(List<String> l) {
        for (final x in l) {
          final v = '${a[x] ?? ''}'.trim();
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      // Kıyıya özgü yer adı (koy, burun, plaj, liman) varsa onu kullan
      final tur = '${j['addresstype'] ?? j['type'] ?? ''}';
      final ozel = '${j['name'] ?? ''}'.trim();
      final kiyi = const {'beach', 'bay', 'cape', 'peninsula', 'harbour', 'pier', 'marina', 'island', 'islet', 'strait'};
      final yer = (kiyi.contains(tur) && ozel.isNotEmpty)
          ? ozel
          : al(['village', 'suburb', 'quarter', 'neighbourhood', 'hamlet', 'town', 'city_district']);
      final ilce = al(['town', 'city_district', 'district', 'county', 'municipality']);
      var ad = yer.isEmpty ? ilce : yer;
      if (ad.isEmpty) return null;
      // "Mahallesi" ekini kısalt
      ad = ad.replaceAll(RegExp(r'\s+Mahallesi$', caseSensitive: false), '');
      if (ilce.isNotEmpty && ilce.toLowerCase() != ad.toLowerCase() && ad.length + ilce.length < 36) ad = '$ad, $ilce';
      if (ad.length > 40) ad = ad.substring(0, 40);
      Side? side;
      final il = al(['province', 'state', 'city']).toLowerCase();
      if (il.contains('stanbul')) {
        side = _anadolu.contains(ilce.toLowerCase()) ? Side.anadolu : Side.avrupa;
      }
      final sonuc = (ad, side);
      _onbellek[k] = sonuc;
      return sonuc;
    } catch (e) {
      debugPrint('yer adı: $e');
      return null;
    }
  }
}
