import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Sepet ve favoriler. Cihazda saklanır; kişisel veri veya ödeme bilgisi içermez.
class AppState extends ChangeNotifier {
  static const _cartKey = 'cart_v1';
  static const _favKey = 'fav_v1';

  final List<CartItem> cart = [];
  final Map<int, ProductCard> favorites = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final c = _prefs!.getString(_cartKey);
      if (c != null) {
        cart
          ..clear()
          ..addAll((jsonDecode(c) as List)
              .map((e) => CartItem.fromJson(e as Map<String, dynamic>)));
      }
      final f = _prefs!.getString(_favKey);
      if (f != null) {
        favorites.clear();
        for (final e in (jsonDecode(f) as List)) {
          final p = ProductCard.fromJson(e as Map<String, dynamic>);
          favorites[p.id] = p;
        }
      }
    } catch (_) {
      // Bozuk kayıt uygulamayı çökertmesin; temiz başla.
      cart.clear();
      favorites.clear();
    }
    memberNotifier.value = isMember;
    notifyListeners();
  }

  /// Üye girişi yapıldı mı? Site oturumu uygulamanın içindeki tarayıcıda tutulur;
  /// başarılı giriş/üyelik sayfası görülünce işaretlenir, çıkışta silinir.
  /// Şifre veya kişisel veri saklanmaz.
  bool get isMember => _prefs?.getBool('member_v1') ?? false;
  Future<void> setMember(bool v) async {
    if (isMember == v) return;
    await _prefs?.setBool('member_v1', v);
    memberNotifier.value = v;
    notifyListeners();
  }

  /// Bildirim izni bir kez soruldu mu?
  bool get notificationAsked => _prefs?.getBool('notif_asked') ?? false;
  Future<void> setNotificationAsked() async => _prefs?.setBool('notif_asked', true);

  void _save() {
    _prefs?.setString(
        _cartKey, jsonEncode(cart.map((e) => e.toJson()).toList()));
    _prefs?.setString(_favKey,
        jsonEncode(favorites.values.map((e) => e.toJson()).toList()));
  }

  int get cartCount => cart.fold(0, (s, e) => s + e.qty);
  double get subtotal => cart.fold(0.0, (s, e) => s + e.total);
  double get remainingForFreeShipping =>
      (AppConfig.freeShippingLimit - subtotal).clamp(0.0, double.infinity);

  void addToCart(CartItem item) {
    final i = cart.indexWhere((e) => e.key == item.key);
    if (i >= 0) {
      cart[i].qty = (cart[i].qty + item.qty).clamp(1, 99);
    } else {
      cart.add(item);
    }
    _save();
    notifyListeners();
  }

  void setQty(CartItem item, int qty) {
    if (qty < 1) {
      cart.remove(item);
    } else {
      item.qty = qty.clamp(1, 99);
    }
    _save();
    notifyListeners();
  }

  void remove(CartItem item) {
    cart.remove(item);
    _save();
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    _save();
    notifyListeners();
  }

  bool isFavorite(int id) => favorites.containsKey(id);

  void toggleFavorite(ProductCard p) {
    if (favorites.containsKey(p.id)) {
      favorites.remove(p.id);
    } else {
      favorites[p.id] = p;
    }
    _save();
    notifyListeners();
  }
}

final appState = AppState();

/// Üyelik durumu değişince kilitli bölümler kendiliğinden açılır/kapanır
final memberNotifier = ValueNotifier<bool>(false);
