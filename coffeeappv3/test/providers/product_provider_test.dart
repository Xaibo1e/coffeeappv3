import 'package:flutter_test/flutter_test.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/product_provider.dart';
import 'package:coffeeappv3/services/product_service.dart';

// Fake ที่ extend ของจริงเพื่อตัด HTTP ออก — จำลอง Backend Offline / Product List
// ว่าง ตาม plan.md ข้อ 49 และ planV2.md ข้อ 57 Session 6 Test Cases
class _FakeProductService extends ProductService {
  final List<Product>? productsToReturn;
  final bool shouldThrow;

  _FakeProductService({this.productsToReturn, this.shouldThrow = false});

  @override
  Future<List<Product>> getProducts(String token) async {
    if (shouldThrow) {
      throw Exception('Cannot load products');
    }
    return productsToReturn ?? [];
  }
}

Product _p(int id, String name, int price, int categoryId) => Product(
      id: id,
      name: name,
      stock: 10,
      price: price,
      categoryId: categoryId,
    );

void main() {
  group('ProductProvider', () {
    test('fetchProducts populates products on success', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: [
          _p(1, 'Americano', 55, 1),
          _p(2, 'Matcha Latte', 80, 2),
        ]),
      );

      await provider.fetchProducts('token');

      expect(provider.products.length, 2);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('fetchProducts sets errorMessage on failure (Backend Offline)', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(shouldThrow: true),
      );

      await provider.fetchProducts('token');

      expect(provider.products, isEmpty);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoading, isFalse);
    });

    test('fetchProducts with an empty list (Product List ว่าง)', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: []),
      );

      await provider.fetchProducts('token');

      expect(provider.products, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    // planV2.md ข้อ 56 Session 5 ชั่วโมงที่ 2: Search Product
    test('filteredProducts filters by search text (case-insensitive)', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: [
          _p(1, 'Americano', 55, 1),
          _p(2, 'Cappuccino', 65, 1),
        ]),
      );
      await provider.fetchProducts('token');

      provider.setSearchText('cappu');

      expect(provider.filteredProducts.length, 1);
      expect(provider.filteredProducts.first.name, 'Cappuccino');
    });

    // planV2.md ข้อ 56 Session 5 ชั่วโมงที่ 3: Filter Category
    test('filteredProducts filters by category', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: [
          _p(1, 'Americano', 55, 1),
          _p(2, 'Matcha Latte', 80, 2),
          _p(3, 'Butter Croissant', 45, 3),
        ]),
      );
      await provider.fetchProducts('token');

      provider.setCategory(3);

      expect(provider.filteredProducts.length, 1);
      expect(provider.filteredProducts.first.name, 'Butter Croissant');
    });

    test('filteredProducts combines search and category filters', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: [
          _p(1, 'Iced Latte', 75, 1),
          _p(2, 'Matcha Latte', 80, 2),
        ]),
      );
      await provider.fetchProducts('token');

      provider.setCategory(1);
      provider.setSearchText('latte');

      expect(provider.filteredProducts.length, 1);
      expect(provider.filteredProducts.first.name, 'Iced Latte');
    });

    test('filteredProducts is empty when search/filter match nothing', () async {
      final provider = ProductProvider(
        productService: _FakeProductService(productsToReturn: [
          _p(1, 'Americano', 55, 1),
        ]),
      );
      await provider.fetchProducts('token');

      provider.setSearchText('zzz');

      expect(provider.filteredProducts, isEmpty);
    });

    // Challenge 2 (plan.md ข้อ 57 / planV2.md ข้อ 59): Sort Product
    group('sort', () {
      late ProductProvider provider;

      setUp(() async {
        provider = ProductProvider(
          productService: _FakeProductService(productsToReturn: [
            _p(1, 'Mocha', 75, 1),
            _p(2, 'Americano', 55, 1),
            _p(3, 'Cappuccino', 65, 1),
          ]),
        );
        await provider.fetchProducts('token');
      });

      test('none keeps the original (backend) order', () {
        expect(
          provider.filteredProducts.map((p) => p.name),
          ['Mocha', 'Americano', 'Cappuccino'],
        );
      });

      test('priceLowHigh sorts ascending by price', () {
        provider.setSortOption(ProductSortOption.priceLowHigh);

        expect(
          provider.filteredProducts.map((p) => p.price),
          [55, 65, 75],
        );
      });

      test('priceHighLow sorts descending by price', () {
        provider.setSortOption(ProductSortOption.priceHighLow);

        expect(
          provider.filteredProducts.map((p) => p.price),
          [75, 65, 55],
        );
      });

      test('nameAZ sorts alphabetically regardless of case', () {
        provider.setSortOption(ProductSortOption.nameAZ);

        expect(
          provider.filteredProducts.map((p) => p.name),
          ['Americano', 'Cappuccino', 'Mocha'],
        );
      });

      test('sort applies after search/filter, not instead of it', () {
        provider.setSearchText('a'); // matches Americano, Mocha, Cappuccino all contain "a"
        provider.setCategory(1);
        provider.setSortOption(ProductSortOption.priceLowHigh);

        expect(
          provider.filteredProducts.map((p) => p.price),
          [55, 65, 75],
        );
      });
    });
  });
}