import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'catches.dart';
import 'config.dart';
import 'hata.dart';
import 'mera.dart';
import 'screens/catch_screens.dart' show ensureCatchToken;

/// Topluluk (profil, Fishkrok, Badimi bul) sunucusu: kiyidanav.com/mobil-topluluk.php
/// Sunucu sayıları bazen metin ("35") döndürür; ikisini de güvenle okur
int? tIntN(Object? v) => v is num ? v.toInt() : (v is String ? (int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt()) : null);
int tInt(Object? v, [int yoksa = 0]) => tIntN(v) ?? yoksa;
double? tDoubleN(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim().replaceAll(',', '.')) : null);
double tDouble(Object? v, [double yoksa = 0]) => tDoubleN(v) ?? yoksa;

class ToplulukHata implements Exception {
  final String mesaj;
  final bool giris;
  const ToplulukHata(this.mesaj, {this.giris = false});
  @override
  String toString() => mesaj;
}

class Topluluk {
  static Uri _uri([Map<String, String> q = const {}]) =>
      Uri.parse('${AppConfig.siteUrl}mobil-topluluk.php').replace(queryParameters: q.isEmpty ? null : q);

  static Map<String, dynamic> _coz(http.Response r) {
    Object? j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ToplulukHata('Sunucu beklenmeyen bir yanıt verdi (kod ${r.statusCode}). Biraz sonra tekrar dene.');
    }
    if (j is Map && j['ok'] == true) return Map<String, dynamic>.from(j);
    final giris = j is Map && j['giris'] == true;
    if (giris) CatchService.saveToken(null);
    throw ToplulukHata(j is Map ? '${j['error'] ?? 'İstek tamamlanamadı.'}' : 'İstek tamamlanamadı.', giris: giris);
  }

  static Future<Map<String, String>> _baslik() async {
    final t = await CatchService.token();
    return {'Accept': 'application/json', if (t != null) 'X-Av-Anahtar': t};
  }

  static Future<Map<String, dynamic>> al(String a, [Map<String, String> q = const {}]) async {
    try {
      final r = await http.get(_uri({'a': a, ...q}), headers: await _baslik()).timeout(const Duration(seconds: 15));
      return _coz(r);
    } on TimeoutException {
      throw const ToplulukHata('Bağlantı çok yavaş. Tekrar dene.');
    } on SocketException {
      throw const ToplulukHata('İnternet bağlantısı yok.');
    } on http.ClientException {
      throw const ToplulukHata('Sunucuya ulaşılamadı. Biraz sonra tekrar dene.');
    }
  }

  static Future<Map<String, dynamic>> gonder(String a, Map<String, String> alanlar,
      {List<String> diziler = const [], String? dosya}) async {
    try {
      final req = http.MultipartRequest('POST', _uri({'a': a}))
        ..followRedirects = false
        ..headers.addAll(await _baslik())
        ..fields.addAll(alanlar);
      // PHP dizi alanları (kamis[]) için tekrar eden anahtarlar
      if (diziler.isNotEmpty) {
        for (var i = 0; i < diziler.length; i++) {
          req.fields['kamis[$i]'] = diziler[i];
        }
      }
      if (dosya != null) req.files.add(await http.MultipartFile.fromPath('foto', dosya, filename: 'profil.jpg'));
      final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
      return _coz(r);
    } on TimeoutException {
      throw const ToplulukHata('Gönderim çok uzun sürdü. Tekrar dene.');
    } on SocketException {
      throw const ToplulukHata('İnternet bağlantısı yok.');
    } on http.ClientException {
      throw const ToplulukHata('Sunucuya ulaşılamadı. Biraz sonra tekrar dene.');
    }
  }

  /// Üye işlemi öncesi: üye değilse davet, anahtar yoksa sitedeki oturumdan alır. Hazırsa true.
  static Future<bool> uyeHazir(BuildContext context, String ne) async {
    if (!appState.isMember) {
      showMemberPrompt(context, ne);
      return false;
    }
    try {
      final t = await ensureCatchToken(context);
      if (t == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Üyeliğin doğrulanamadı. Hesabım › Giriş yap ile yeniden giriş yapıp tekrar dene.')));
      }
      return t != null;
    } catch (e) {
      Hata.goster('$e');
      return false;
    }
  }

  static String get platform => Platform.isIOS ? 'ios' : 'android';
}
