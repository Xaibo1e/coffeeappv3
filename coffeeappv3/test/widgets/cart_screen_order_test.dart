import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffeeappv3/models/cart_item.dart';
import 'package:coffeeappv3/models/order.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/auth_provider.dart';
import 'package:coffeeappv3/providers/cart_provider.dart';
import 'package:coffeeappv3/providers/order_provider.dart';
import 'package:coffeeappv3/providers/product_provider.dart';
import 'package:coffeeappv3/screens/cart_screen.dart';
import 'package:coffeeappv3/services/auth_service.dart';
import 'package:coffeeappv3/services/order_service.dart';
import 'package:coffeeappv3/services/product_service.dart';

// feature.md A2 (ปิด G2) — เกณฑ์ผ่านข้อสำคัญที่สุดของ Feature นี้
//
// จุดพลาดคลาสสิกคือเรียก clearCart() ก่อนรู้ผลจาก API ถ้าพลาดตรงนี้ ผู้ใช้ที่สั่งเกิน
// stock จะเสียตะกร้าทั้งใบไปโดยไม่ได้อะไรกลับมาเลย test คู่นี้ล็อกพฤติกรรมนั้นไว้

class _FakeOrderService extends OrderService {
  final bool shouldFail;
  _FakeOrderService({this.shouldFail = false});

  @override
  Future<Order> createOrder({
    required String token,
    required List<CartItem> items,
  }) async {
    if (shouldFail) {
      throw Exception('Insufficient stock for product_id 1 (have 1, requested 2)');
    }

    return Order.fromJson({
      'id': 99,
      'status': 'confirmed',
      'total_price': 130,
      'items': const [],
    });
  }
}

class _FakeProductService extends ProductService {
  @override
  Future<List<Product>> getProducts(String token) async => const [];
}

class _StubAuthService extends AuthService {}

class _AuthWithToken extends AuthProvider {
  _AuthWithToken() : super(authService: _StubAuthService()) {
    token = 'fake-token';
  }
}

Widget _cartApp({
  required CartProvider cart,
  required OrderProvider orders,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _AuthWithToken()),
      ChangeNotifierProvider<CartProvider>.value(value: cart),
      ChangeNotifierProvider<OrderProvider>.value(value: orders),
      ChangeNotifierProvider(
        create: (_) => ProductProvider(productService: _FakeProductService()),
      ),
    ],
    child: const MaterialApp(home: CartScreen()),
  );
}

CartProvider _cartWithOneItem() {
  final cart = CartProvider();
  cart.addItem(
    Product(id: 1, name: 'Cappuccino', stock: 10, price: 65, categoryId: 1),
  );
  return cart;
}

// เรียก onPressed ตรง ๆ แทน tester.tap() โดยตั้งใจ
//
// tester.tap() จะจุด ink splash ของ Material ซึ่งต้องโหลด shader
// `shaders/ink_sparkle.frag` — บน Flutter 3.44 บางเครื่อง shader นี้โหลดไม่ผ่านและ
// ทำให้ test ล้มด้วยเหตุที่ไม่เกี่ยวกับสิ่งที่กำลังทดสอบเลย (ดูคำเตือนในบทเรียน
// testing ของ tutorial-site) การเรียก callback ตรงจึงทดสอบพฤติกรรมเดียวกันได้
// โดยไม่ต้องพึ่ง rendering pipeline
Future<void> _pressConfirmOrder(WidgetTester tester) async {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Confirm Order'),
  );

  button.onPressed!();

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a failed order keeps the cart intact', (tester) async {
    final cart = _cartWithOneItem();
    final orders = OrderProvider(
      orderService: _FakeOrderService(shouldFail: true),
    );

    await tester.pumpWidget(_cartApp(cart: cart, orders: orders));

    expect(cart.totalItems, 1);

    await _pressConfirmOrder(tester);

    expect(cart.totalItems, 1, reason: 'ตะกร้าต้องไม่ถูกล้างเมื่อ API ล้มเหลว');
    expect(orders.placeOrderError, contains('Insufficient stock'));
  });

  testWidgets('a successful order clears the cart', (tester) async {
    final cart = _cartWithOneItem();
    final orders = OrderProvider(orderService: _FakeOrderService());

    await tester.pumpWidget(_cartApp(cart: cart, orders: orders));

    await _pressConfirmOrder(tester);

    expect(cart.totalItems, 0);
    expect(orders.orders.single.id, 99);
  });
}