import 'package:flutter_test/flutter_test.dart';
import 'package:coffeeappv3/models/cart_item.dart';
import 'package:coffeeappv3/models/order.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/order_provider.dart';
import 'package:coffeeappv3/services/order_service.dart';

// feature.md A2 (ปิด G2) — Order API
//
// Fake ที่ extend ของจริงเพื่อตัด HTTP ออก แบบเดียวกับ _FakeAuthService
class _FakeOrderService extends OrderService {
  final String? failWith;
  int createCallCount = 0;

  _FakeOrderService({this.failWith});

  @override
  Future<Order> createOrder({
    required String token,
    required List<CartItem> items,
  }) async {
    createCallCount++;

    if (failWith != null) throw Exception(failWith);

    // จำลองพฤติกรรมสำคัญของ server: ราคาที่คืนมาคำนวณจาก DB ไม่ใช่จากที่ client ส่ง
    final lines = items
        .map((item) => {
              'product_id': item.product.id,
              'product_name': item.product.name,
              'unit_price': item.product.price,
              'quantity': item.quantity,
              'subtotal': item.product.price * item.quantity,
            })
        .toList();

    return Order.fromJson({
      'id': 99,
      'status': 'confirmed',
      'total_price': lines.fold<int>(
        0,
        (sum, line) => sum + (line['subtotal'] as int),
      ),
      'items': lines,
    });
  }

  @override
  Future<List<Order>> getOrders(String token) async {
    if (failWith != null) throw Exception(failWith);

    return [
      Order.fromJson({'id': 2, 'status': 'confirmed', 'total_price': 65}),
      Order.fromJson({'id': 1, 'status': 'confirmed', 'total_price': 205}),
    ];
  }

  @override
  Future<Order> getOrderById(String token, int id) async {
    if (failWith != null) throw Exception(failWith);

    return Order.fromJson({
      'id': id,
      'status': 'confirmed',
      'total_price': 130,
      'items': [
        {
          'product_id': 3,
          'product_name': 'Cappuccino',
          'unit_price': 65,
          'quantity': 2,
          'subtotal': 130,
        },
      ],
    });
  }
}

Product _product({int id = 1, int price = 65, int stock = 10}) => Product(
      id: id,
      name: 'Cappuccino',
      stock: stock,
      price: price,
      categoryId: 1,
    );

void main() {
  group('OrderProvider', () {
    test('createOrder returns the order and puts it on top of the history', () async {
      final provider = OrderProvider(orderService: _FakeOrderService());

      final order = await provider.createOrder(
        token: 'token',
        items: [CartItem(product: _product(), quantity: 2)],
      );

      expect(order, isNotNull);
      expect(order!.id, 99);
      expect(order.totalPrice, 130);
      expect(provider.placeOrderError, isNull);
      expect(provider.isPlacingOrder, isFalse);

      // ผู้ใช้ต้องเห็นรายการใหม่ทันทีโดยไม่ต้องรอ fetchOrders() รอบใหม่
      expect(provider.orders.first.id, 99);
    });

    // เกณฑ์ผ่านข้อสำคัญที่สุดของ A2: สั่งเกิน stock แล้วต้องไม่มีอะไรถูกบันทึก
    test('createOrder returns null and reports the server message when it fails', () async {
      final provider = OrderProvider(
        orderService: _FakeOrderService(
          failWith: 'Insufficient stock for product_id 1 (have 1, requested 2)',
        ),
      );

      final order = await provider.createOrder(
        token: 'token',
        items: [CartItem(product: _product(stock: 1), quantity: 2)],
      );

      expect(order, isNull);
      expect(provider.placeOrderError, contains('Insufficient stock'));
      expect(provider.isPlacingOrder, isFalse);

      // ไม่มี Order ปลอมถูกเติมเข้าประวัติเมื่อ API ล้มเหลว
      expect(provider.orders, isEmpty);
    });

    test('createOrder uses the price from the server, not from the cart', () async {
      final provider = OrderProvider(orderService: _FakeOrderService());

      final order = await provider.createOrder(
        token: 'token',
        items: [CartItem(product: _product(price: 65), quantity: 3)],
      );

      expect(order!.items.single.unitPrice, 65);
      expect(order.items.single.subtotal, 195);
      expect(order.totalPrice, 195);
    });

    test('fetchOrders loads the history newest first', () async {
      final provider = OrderProvider(orderService: _FakeOrderService());

      await provider.fetchOrders('token');

      expect(provider.orders.length, 2);
      expect(provider.orders.first.id, 2);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('fetchOrders keeps the error message when the API fails', () async {
      final provider = OrderProvider(
        orderService: _FakeOrderService(failWith: 'Cannot load orders'),
      );

      await provider.fetchOrders('token');

      expect(provider.orders, isEmpty);
      expect(provider.errorMessage, 'Cannot load orders');
      expect(provider.isLoading, isFalse);
    });

    test('fetchOrderById loads the snapshot items of one order', () async {
      final provider = OrderProvider(orderService: _FakeOrderService());

      await provider.fetchOrderById('token', 7);

      expect(provider.selectedOrder?.id, 7);
      expect(provider.selectedOrder?.items.single.productName, 'Cappuccino');
      expect(provider.selectedOrder?.totalItems, 2);
    });

    // GET /api/orders/:id ของคนอื่นต้องได้ 403 — ฝั่งแอปต้องแสดง error ไม่ใช่ค้างหน้าว่าง
    test('fetchOrderById surfaces Forbidden and clears the previous order', () async {
      final provider = OrderProvider(
        orderService: _FakeOrderService(failWith: 'Forbidden'),
      );

      await provider.fetchOrderById('token', 7);

      expect(provider.selectedOrder, isNull);
      expect(provider.errorMessage, 'Forbidden');
    });
  });
}