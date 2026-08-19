import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persists the logged-in [Session] so the user doesn't have to sign in
/// again every time the app is closed and reopened.
class SessionStore {
  static const _key = 'session';

  static Future<void> save(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  static Future<Session?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Persists the customer's cart so items aren't lost when the app restarts.
/// Prices/stock are cached as of the moment items were added; they are
/// refreshed from the server the next time the product list loads.
class CartStore {
  static const _key = 'cart';

  static Future<void> save(List<Product> cart) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(cart.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<List<Product>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Product.fromCacheJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
