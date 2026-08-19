import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kukupaja_app/core/local_store.dart';
import 'package:kukupaja_app/models/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionStore', () {
    test('returns null when nothing has been saved', () async {
      expect(await SessionStore.load(), isNull);
    });

    test('saves and restores a session across "restarts"', () async {
      const session = Session('tok-abc', 9, 'Neema', 'customer');
      await SessionStore.save(session);

      final restored = await SessionStore.load();

      expect(restored, isNotNull);
      expect(restored!.token, 'tok-abc');
      expect(restored.userId, 9);
      expect(restored.role, 'customer');
    });

    test('clear removes the saved session', () async {
      await SessionStore.save(const Session('tok', 1, 'A', 'customer'));
      await SessionStore.clear();

      expect(await SessionStore.load(), isNull);
    });
  });

  group('CartStore', () {
    const product = Product(
      1,
      'Kuku wa Kienyeji',
      'Morogoro',
      15000,
      28,
      'https://example.com/kuku.jpg',
      'kienyeji',
    );

    test('returns an empty cart when nothing has been saved', () async {
      expect(await CartStore.load(), isEmpty);
    });

    test('saves and restores cart items in order', () async {
      await CartStore.save([product, product]);

      final restored = await CartStore.load();

      expect(restored.length, 2);
      expect(restored.first.id, product.id);
      expect(restored.first.price, product.price);
    });

    test('clear empties the saved cart', () async {
      await CartStore.save([product]);
      await CartStore.clear();

      expect(await CartStore.load(), isEmpty);
    });
  });
}
