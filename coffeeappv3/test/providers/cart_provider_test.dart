import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/cart_provider.dart';

// planV2.md ข้อ 57 Session 6: Integration Test — ครอบคลุม Cart Test Cases จาก
// plan.md ข้อ 60 (Add Product, Add Product ซ้ำ, Increase, Decrease, Remove,
// Total Items, Total Price, Clear Cart) และ Quantity = 0 จาก Session 6 Test Cases
Product _product({
  int id = 1,
  String name = 'Americano',
  int price = 55,
  int stock = 20,
}) {
  return Product(
    id: id,
    name: name,
    stock: stock,
    price: price,
    categoryId: 1,
  );
}

void main() {
  // feature.md A3 (ปิด G3): Provider ตัวนี้เขียนลง SharedPreferences แล้ว
  // ต้องเตรียม binding และ mock storage ให้ก่อน ไม่งั้นทุก test จะล้มด้วย
  // MissingPluginException ตั้งแต่บรรทัดแรกที่แตะตะกร้า
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartProvider', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
    });

    test('addItem adds a new product with quantity 1', () {
      cart.addItem(_product());

      expect(cart.items.length, 1);
      expect(cart.items[1]!.quantity, 1);
    });

    test('addItem on an existing product increases quantity instead of duplicating', () {
      final product = _product();
      cart.addItem(product);
      cart.addItem(product);

      expect(cart.items.length, 1);
      expect(cart.items[1]!.quantity, 2);
    });

    test('increaseQuantity increments quantity', () {
      cart.addItem(_product());
      cart.increaseQuantity(1);

      expect(cart.items[1]!.quantity, 2);
    });

    test('decreaseQuantity decrements quantity', () {
      cart.addItem(_product());
      cart.increaseQuantity(1);
      cart.decreaseQuantity(1);

      expect(cart.items[1]!.quantity, 1);
    });

    test('decreaseQuantity removes the item once quantity reaches 0', () {
      cart.addItem(_product());
      cart.decreaseQuantity(1);

      expect(cart.items.containsKey(1), isFalse);
    });

    test('removeItem removes the product regardless of its quantity', () {
      final product = _product();
      cart.addItem(product);
      cart.addItem(product);
      cart.removeItem(1);

      expect(cart.items.containsKey(1), isFalse);
    });

    test('totalItems sums quantities across every product', () {
      cart.addItem(_product(id: 1, price: 55));
      cart.addItem(_product(id: 2, price: 65));
      cart.increaseQuantity(1);

      expect(cart.totalItems, 3);
    });

    test('totalPrice sums subtotal (price x quantity) across every product', () {
      cart.addItem(_product(id: 1, price: 55));
      cart.increaseQuantity(1);
      cart.addItem(_product(id: 2, price: 65));

      expect(cart.totalPrice, 175);
    });

    test('clearCart empties the cart', () {
      cart.addItem(_product());
      cart.clearCart();

      expect(cart.items, isEmpty);
      expect(cart.totalItems, 0);
      expect(cart.totalPrice, 0);
    });

    test('notifies listeners when the cart changes', () {
      var notified = false;
      cart.addListener(() => notified = true);

      cart.addItem(_product());

      expect(notified, isTrue);
    });

    // Challenge 3 (plan.md ข้อ 57 / planV2.md ข้อ 59): Product Stock Validation
    group('stock validation', () {
      test('addItem returns true and succeeds while under stock', () {
        final result = cart.addItem(_product(stock: 2));
        expect(result, isTrue);
        expect(cart.items[1]!.quantity, 1);
      });

      test('addItem returns false and stops once quantity reaches stock', () {
        final product = _product(stock: 2);
        cart.addItem(product); // qty 1
        cart.addItem(product); // qty 2 (at cap)
        final result = cart.addItem(product); // should be rejected

        expect(result, isFalse);
        expect(cart.items[1]!.quantity, 2);
      });

      test('addItem rejects a product with zero stock outright', () {
        final result = cart.addItem(_product(stock: 0));

        expect(result, isFalse);
        expect(cart.items.containsKey(1), isFalse);
      });

      test('increaseQuantity returns false and stops once quantity reaches stock', () {
        cart.addItem(_product(stock: 2));
        cart.increaseQuantity(1); // qty 2 (at cap)
        final result = cart.increaseQuantity(1); // should be rejected

        expect(result, isFalse);
        expect(cart.items[1]!.quantity, 2);
      });
    });
  });

  // feature.md A3 (ปิด G3) — Persist Cart
  group('CartProvider persistence', () {
    test('a cart survives closing and reopening the app', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: 1, price: 55));
      cart.addItem(_product(id: 1, price: 55));
      cart.addItem(_product(id: 2, name: 'Latte', price: 65));

      // ให้ _persist() ที่เป็น fire-and-forget เขียนจบก่อน
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // ตัวแทน Provider ใหม่ที่ถูกสร้างตอนเปิดแอปใหม่ (cold start)
      final reopened = CartProvider();
      await reopened.restore();

      expect(reopened.totalItems, 3);
      expect(reopened.items[1]!.quantity, 2);
      expect(reopened.items[2]!.product.name, 'Latte');
      expect(reopened.totalPrice, 55 * 2 + 65);
    });

    test('clearing the cart also clears what was saved', () async {
      final cart = CartProvider();
      cart.addItem(_product());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      cart.clearCart();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final reopened = CartProvider();
      await reopened.restore();

      expect(reopened.items, isEmpty);
    });

    // คำถามออกแบบของ Feature นี้: ราคาเปลี่ยนหลังเก็บตะกร้าไว้ ควรใช้ราคาไหน?
    // ตอบ: ราคาปัจจุบัน เพราะยังไม่ได้จ่ายเงิน (ต่างจาก order_items ที่ Snapshot ไว้)
    test('syncWithProducts refreshes the price from the API', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: 1, price: 55));

      cart.syncWithProducts([_product(id: 1, price: 60)]);

      expect(cart.items[1]!.product.price, 60);
      expect(cart.totalPrice, 60);
    });

    test('syncWithProducts caps the quantity when stock has dropped', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: 1, stock: 20));
      cart.addItem(_product(id: 1, stock: 20));
      cart.addItem(_product(id: 1, stock: 20));

      cart.syncWithProducts([_product(id: 1, stock: 2)]);

      expect(cart.items[1]!.quantity, 2);
    });

    test('syncWithProducts drops a product that no longer exists', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: 1));
      cart.addItem(_product(id: 2, name: 'Latte'));

      // Admin ลบสินค้า id 2 ไปแล้ว — ถ้าปล่อยไว้ กดสั่งซื้อจะได้ error จาก server
      cart.syncWithProducts([_product(id: 1)]);

      expect(cart.items.containsKey(2), isFalse);
      expect(cart.items.containsKey(1), isTrue);
    });
  });
}