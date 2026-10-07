import 'dart:convert';
import '../config/api_config.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import 'api_client.dart';

// feature.md A2 (ปิด G2) — Order API
//
// หลัง B3 ทุก endpoint ในระบบตอบ HTTP status code จริงแล้ว การตรวจ error จึงย้าย
// ไปอยู่ใน ApiClient ที่เดียว — ไฟล์นี้เหลือแค่เรื่องแปลง JSON เป็น Order
class OrderService {
  // feature.md B2: ใช้ ApiClient ตัวเดียวกับ ProductService — กฎเรื่อง 401 และการ
  // อ่านข้อความ error จาก body อยู่ที่นั่นที่เดียว
  final ApiClient apiClient;

  OrderService({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient();

  Future<Order> createOrder({
    required String token,
    required List<CartItem> items,
  }) async {
    final response = await apiClient.post(
      ApiConfig.orders,
      token: token,
      // ส่งแค่ product_id กับ quantity — ไม่ส่งราคา เพราะ server คำนวณราคาจาก DB เอง
      // ถ้าส่งราคาไปด้วย server ก็ไม่ควรเชื่ออยู่ดี การไม่ส่งจึงชัดเจนกว่า
      body: {
        'items': items
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> getOrders(String token) async {
    final response = await apiClient.get(ApiConfig.orders, token: token);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['orders'] as List;

    return list
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Order> getOrderById(String token, int id) async {
    final response = await apiClient.get(
      ApiConfig.orderById(id),
      token: token,
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Order API คืน Object เดี่ยวตรง ๆ จึงไม่ต้องมีโค้ดพิเศษรองรับ Array แบบที่
    // ProductService.getProductById() ต้องเขียน (ดู feature.md G7)
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }
}