import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/favorite_provider.dart';

// Challenge 1 (plan.md ข้อ 57 / planV2.md ข้อ 59): Favorite
Product _product({int id = 1, String name = 'Americano'}) {
  return Product(id: id, name: name, stock: 20, price: 55, categoryId: 1);
}

void main() {
  // feature.md A3 (ปิด G3): Provider ตัวนี้เขียนลง SharedPreferences แล้ว
  // ต้องเตรียม binding และ mock storage ให้ก่อน ไม่งั้นทุก test จะล้มด้วย
  // MissingPluginException ตั้งแต่บรรทัดแรกที่แตะตะกร้า
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoriteProvider', () {
    late FavoriteProvider favorites;

    setUp(() {
      favorites = FavoriteProvider();
    });

    test('a product starts out not favorited', () {
      expect(favorites.isFavorite(1), isFalse);
    });

    test('toggleFavorite adds a product to favorites', () {
      favorites.toggleFavorite(_product());

      expect(favorites.isFavorite(1), isTrue);
      expect(favorites.favorites, hasLength(1));
    });

    test('toggleFavorite twice removes it again', () {
      final product = _product();
      favorites.toggleFavorite(product);
      favorites.toggleFavorite(product);

      expect(favorites.isFavorite(1), isFalse);
      expect(favorites.favorites, isEmpty);
    });

    test('tracks multiple distinct products independently', () {
      favorites.toggleFavorite(_product(id: 1, name: 'Americano'));
      favorites.toggleFavorite(_product(id: 2, name: 'Cappuccino'));

      expect(favorites.favorites, hasLength(2));
      expect(favorites.isFavorite(1), isTrue);
      expect(favorites.isFavorite(2), isTrue);

      favorites.toggleFavorite(_product(id: 1, name: 'Americano'));

      expect(favorites.isFavorite(1), isFalse);
      expect(favorites.isFavorite(2), isTrue);
      expect(favorites.favorites, hasLength(1));
    });

    test('notifies listeners on toggle', () {
      var notified = false;
      favorites.addListener(() => notified = true);

      favorites.toggleFavorite(_product());

      expect(notified, isTrue);
    });
  });

  // feature.md A3 (ปิด G3) — Persist Favorite
  group('FavoriteProvider persistence', () {
    test('favorites survive closing and reopening the app', () async {
      final favorites = FavoriteProvider();
      favorites.toggleFavorite(_product(id: 1));
      favorites.toggleFavorite(_product(id: 2, name: 'Latte'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final reopened = FavoriteProvider();
      await reopened.restore();

      expect(reopened.favorites.length, 2);
      expect(reopened.isFavorite(1), isTrue);
      expect(reopened.isFavorite(2), isTrue);
    });

    test('un-favouriting everything clears what was saved', () async {
      final favorites = FavoriteProvider();
      favorites.toggleFavorite(_product(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      favorites.toggleFavorite(_product(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final reopened = FavoriteProvider();
      await reopened.restore();

      expect(reopened.favorites, isEmpty);
    });

    test('syncWithProducts drops a product that no longer exists', () async {
      final favorites = FavoriteProvider();
      favorites.toggleFavorite(_product(id: 1));
      favorites.toggleFavorite(_product(id: 2, name: 'Latte'));

      favorites.syncWithProducts([_product(id: 1)]);

      expect(favorites.isFavorite(2), isFalse);
      expect(favorites.isFavorite(1), isTrue);
    });
  });
}