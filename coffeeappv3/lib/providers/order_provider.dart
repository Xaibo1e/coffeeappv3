import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/order_service.dart';

// feature.md A2 (ปิด G2) — State ของประวัติการสั่งซื้อและการสั่งซื้อ
//
// แยก isPlacingOrder/placeOrderError ออกจาก isLoading/errorMessage ด้วยเหตุผลเดียว
// กับที่ ProductProvider แยก isSaving ออกจาก isLoading — การกดสั่งซื้อไม่ควรทำให้
// หน้าประวัติขึ้น spinner และ error ของคนละงานไม่ควรไปโผล่ผิดที่
class OrderProvider extends ChangeNotifier {
  final OrderService orderService;

  List<Order> orders = [];
  Order? selectedOrder;

  bool isLoading = false;
  String? errorMessage;

  bool isPlacingOrder = false;
  String? placeOrderError;

  OrderProvider({
    required this.orderService,
  });

  Future<void> fetchOrders(String token) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      orders = await orderService.getOrders(token);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOrderById(String token, int id) async {
    isLoading = true;
    errorMessage = null;
    selectedOrder = null;
    notifyListeners();

    try {
      selectedOrder = await orderService.getOrderById(token, id);
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// คืน Order ที่สร้างสำเร็จ หรือ null เมื่อล้มเหลว (ดูเหตุผลได้จาก placeOrderError)
  ///
  /// จงใจคืน Order? แทน bool เพราะหน้า Cart ต้องใช้เลขที่ Order ไปแสดงใน Dialog
  /// และผู้เรียกต้องแยกให้ออกว่า "สำเร็จ" กับ "ล้มเหลว" ก่อนตัดสินใจล้างตะกร้า
  Future<Order?> createOrder({
    required String token,
    required List<CartItem> items,
  }) async {
    isPlacingOrder = true;
    placeOrderError = null;
    notifyListeners();

    try {
      final order = await orderService.createOrder(token: token, items: items);

      // สั่งซื้อสำเร็จแล้วประวัติที่โหลดไว้ก่อนหน้าย่อมไม่ครบ — เติมตัวใหม่ขึ้นหัว
      // เลย ผู้ใช้จะได้เห็นทันทีโดยไม่ต้องรอ fetchOrders() รอบใหม่
      orders = [order, ...orders];
      return order;
    } catch (e) {
      placeOrderError = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isPlacingOrder = false;
      notifyListeners();
    }
  }
}