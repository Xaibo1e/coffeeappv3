import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  // feature.md A3 (ปิด G3): เก็บลงเครื่อง ไม่ได้เก็บที่ backend เพราะยังไม่มี Cart API
  // (Order API ใน A2 บันทึกเฉพาะตอนกดสั่งซื้อจบแล้ว ไม่ใช่ตะกร้าระหว่างเลือกของ)
  static const _storageKey = 'cart_items';

  final Map<int, CartItem> _items = {};

  Map<int, CartItem> get items => _items;

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  int get totalPrice =>
      _items.values.fold(0, (sum, item) => sum + item.subtotal);

  // Challenge 3 (plan.md ข้อ 57 / planV2.md ข้อ 59): ห้ามเพิ่มสินค้าเกิน product.stock
  // คืนค่า false เมื่อชนขีดจำกัด เพื่อให้ UI แสดงข้อความแจ้งผู้ใช้ได้
  bool addItem(Product product) {
    final existing = _items[product.id];

    if (existing != null) {
      if (existing.quantity >= product.stock) return false;
      existing.quantity++;
    } else {
      if (product.stock <= 0) return false;
      _items[product.id] = CartItem(product: product);
    }

    _persist();
    notifyListeners();
    return true;
  }

  bool increaseQuantity(int productId) {
    final item = _items[productId];
    if (item == null) return false;
    if (item.quantity >= item.product.stock) return false;

    item.quantity++;
    _persist();
    notifyListeners();
    return true;
  }

  void decreaseQuantity(int productId) {
    if (!_items.containsKey(productId)) return;

    _items[productId]!.quantity--;

    if (_items[productId]!.quantity <= 0) {
      _items.remove(productId);
    }

    _persist();
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    _persist();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _persist();
    notifyListeners();
  }

  /// อ่านตะกร้าที่บันทึกไว้กลับมา — เรียกครั้งเดียวตอนเปิดแอป (ดู SplashScreen)
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null) return;

    try {
      final list = jsonDecode(saved) as List;

      _items.clear();
      for (final raw in list) {
        final item = CartItem.fromJson(raw as Map<String, dynamic>);
        _items[item.product.id] = item;
      }

      notifyListeners();
    } catch (_) {
      // ข้อมูลที่เก็บไว้เสียหรือมาจากโครงสร้างรุ่นเก่า — ทิ้งแล้วเริ่มใหม่ ดีกว่า
      // ปล่อยให้แอป crash ตอนเปิดจนผู้ใช้เข้าใช้งานไม่ได้เลย
      await prefs.remove(_storageKey);
    }
  }

  /// อัปเดตสินค้าในตะกร้าให้ตรงกับข้อมูลล่าสุดจาก API
  ///
  /// ตะกร้าที่ถูกเก็บไว้ข้ามวันอาจถือราคาเก่า หรือถือสินค้าที่ Admin ลบไปแล้ว —
  /// เรียกทุกครั้งหลังโหลดรายการสินค้าเสร็จ (ดู HomeScreen)
  void syncWithProducts(List<Product> products) {
    if (products.isEmpty || _items.isEmpty) return;

    final latest = {for (final product in products) product.id: product};
    var changed = false;

    for (final productId in _items.keys.toList()) {
      final product = latest[productId];

      if (product == null) {
        // สินค้าถูกลบไปแล้ว — เอาออกจากตะกร้า ไม่งั้นกดสั่งซื้อจะได้ error จาก server
        _items.remove(productId);
        changed = true;
        continue;
      }

      final synced = _items[productId]!.withProduct(product);
      if (synced.quantity <= 0) {
        _items.remove(productId);
      } else {
        _items[productId] = synced;
      }
      changed = true;
    }

    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  // fire-and-forget แบบเดียวกับ AuthProvider._saveSession() — การเขียนลงดิสก์ไม่ควร
  // ทำให้ UI ค้างรอ และถ้าเขียนไม่สำเร็จก็ยังใช้ตะกร้าในรอบนี้ต่อได้ตามปกติ
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    if (_items.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(_items.values.map((item) => item.toJson()).toList()),
    );
  }
}