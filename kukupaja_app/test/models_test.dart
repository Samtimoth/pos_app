import 'package:flutter_test/flutter_test.dart';
import 'package:kukupaja_app/models/models.dart';

void main() {
  group('Product', () {
    test('fromJson parses server fields into typed values', () {
      final product = Product.fromJson({
        'id': '7',
        'name': 'Kuku wa Kienyeji',
        'location': 'Dodoma',
        'customer_price': '20000',
        'available_stock': '12',
        'image_url': 'https://example.com/kuku.jpg',
        'category': 'kienyeji',
      });

      expect(product.id, 7);
      expect(product.price, 20000);
      expect(product.stock, 12);
      expect(product.category, 'kienyeji');
    });

    test('fromJson parses a decimal-string price from the real API shape', () {
      // MySQL DECIMAL columns are returned by PDO as strings like "10000.00",
      // not plain integers - int.parse on that string throws, which used to
      // get swallowed by ApiService.products()'s catch-all and silently fall
      // back to demo data.
      final product = Product.fromJson({
        'id': 14,
        'name': 'kuku mayai',
        'location': 'uzunguni',
        'customer_price': '10000.00',
        'available_stock': 65,
        'category': 'mayai',
      });

      expect(product.price, 10000);
      expect(product.stock, 65);
    });

    test('fromJson defaults category and image when missing', () {
      final product = Product.fromJson({
        'id': 1,
        'name': 'Kuku',
        'location': 'Arusha',
        'customer_price': 10000,
        'available_stock': 5,
      });

      expect(product.category, 'vingine');
      expect(product.image, '');
    });

    test('toJson / fromCacheJson round-trips a product for local storage', () {
      const product = Product(
        3,
        'Kuku wa Mayai',
        'Pwani',
        18000,
        35,
        'https://example.com/eggs.jpg',
        'mayai',
      );

      final restored = Product.fromCacheJson(product.toJson());

      expect(restored.id, product.id);
      expect(restored.name, product.name);
      expect(restored.price, product.price);
      expect(restored.stock, product.stock);
      expect(restored.category, product.category);
    });
  });

  group('Session', () {
    test('toJson / fromJson round-trips a logged-in session', () {
      const session = Session('tok-123', 42, 'Ally M.', 'broker');

      final restored = Session.fromJson(session.toJson());

      expect(restored.token, session.token);
      expect(restored.userId, session.userId);
      expect(restored.name, session.name);
      expect(restored.role, session.role);
    });
  });

  group('Advertisement', () {
    test('fromJson falls back to defaults for optional fields', () {
      final ad = Advertisement.fromJson({
        'id': '5',
        'advertiser_name': 'KukuPaja',
        'title': 'Ofa Maalum',
      });

      expect(ad.id, 5);
      expect(ad.subtitle, '');
      expect(ad.buttonText, 'Angalia Sasa');
      expect(ad.category, 'wote');
    });
  });
}
