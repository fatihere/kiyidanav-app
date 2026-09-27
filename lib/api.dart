import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'demo_data.dart';
import 'models.dart';

/// Sunucu isteği reddetti (ör. "Ürün bulunamadı"). Mesaj kullanıcıya gösterilebilir.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Sunucuya ulaşılamadı veya API henüz yüklenmemiş.
class ApiUnavailable implements Exception {
  const ApiUnavailable();
  @override
  String toString() =>
      'Mağazaya bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.';
}

class Api {
  static final http.Client _client = http.Client();

  /// Örnek verilerle mi çalışıyoruz?
  static bool demo = false;

  static Future<Map<String, dynamic>> _get(Map<String, String> q) async {
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: q);
    if (uri.scheme != 'https') throw const ApiUnavailable(); // şifresiz bağlantı yok
    http.Response res;
    try {
      res = await _client.get(uri, headers: const {
        'Accept': 'application/json',
        'User-Agent': 'KiyidanAv-Android/1.0',
      }).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const ApiUnavailable();
    } on SocketException {
      throw const ApiUnavailable();
    } on http.ClientException {
      throw const ApiUnavailable();
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      // HTML sayfa döndü → API dosyası henüz yok
      throw const ApiUnavailable();
    }
    if (j['ok'] != true) {
      throw ApiException(
          (j['error'] ?? 'İstek tamamlanamadı.').toString());
    }
    return j;
  }

  static Future<T> _withDemo<T>(
      Future<T> Function() real, T Function() fake) async {
    if (demo && AppConfig.demoFallback) return fake();
    try {
      final r = await real();
      demo = false;
      return r;
    } on ApiUnavailable {
      if (!AppConfig.demoFallback) rethrow;
      demo = true;
      return fake();
    }
  }

  static Future<HomeData> home() => _withDemo(
      () async => HomeData.fromJson(await _get({'a': 'home'})),
      DemoData.home);

  static Future<List<Category>> categories(int parent) => _withDemo(
        () async {
          final j = await _get({'a': 'categories', 'parent': '$parent'});
          return ((j['items'] as List?) ?? [])
              .map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList();
        },
        () => DemoData.categories(parent),
      );

  static Future<PageResult> products(int category,
          {int page = 1, String sort = 'new'}) =>
      _withDemo(
        () async => PageResult.fromJson(await _get({
          'a': 'products',
          'category': '$category',
          'page': '$page',
          'sort': sort,
        })),
        () => DemoData.products(category: category, sort: sort),
      );

  static Future<PageResult> search(String q, {int page = 1}) => _withDemo(
        () async => PageResult.fromJson(
            await _get({'a': 'search', 'q': q, 'page': '$page'})),
        () => DemoData.search(q),
      );

  static Future<ProductDetail> product(int id) => _withDemo(
      () async => ProductDetail.fromJson(
          await _get({'a': 'product', 'id': '$id'})),
      () => DemoData.product(id));
}
