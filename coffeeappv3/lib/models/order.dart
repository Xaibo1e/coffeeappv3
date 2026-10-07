// feature.md A2 (ปิด G2) — Order + OrderItem
//
// รูปร่างตรงกับ response ของ Order API ที่ออกแบบไว้ใน challenges.md ข้อ 6
//
// สังเกตว่า OrderItem เก็บ productName/unitPrice ไว้ในตัวเอง ไม่ได้ถือ Product
// เหมือน CartItem เพราะฝั่ง server เก็บเป็น Snapshot ณ เวลาที่สั่ง — ราคาที่แสดงใน
// ประวัติต้องเป็นราคาที่จ่ายจริงวันนั้น ไม่ใช่ราคาปัจจุบันที่ Admin อาจแก้ไปแล้ว
class OrderItem {
  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final int subtotal;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: _toInt(json['product_id']),
      productName: json['product_name'] ?? '',
      unitPrice: _toInt(json['unit_price']),
      quantity: _toInt(json['quantity']),
      subtotal: _toInt(json['subtotal']),
    );
  }
}

class Order {
  final int id;
  final String status;
  final int totalPrice;
  final DateTime? createdAt;

  // ว่างเสมอสำหรับ Order ที่มาจาก GET /api/orders (endpoint นั้นคืนแบบสรุปเพื่อให้
  // response เบา) รายการเต็มมากับ GET /api/orders/:id เท่านั้น
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.totalPrice,
    this.createdAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return Order(
      id: _toInt(json['id']),
      status: json['status'] ?? 'confirmed',
      totalPrice: _toInt(json['total_price']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      items: rawItems is List
          ? rawItems
              .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}

// เหตุผลเดียวกับ Product._toInt: MySQL ส่งตัวเลขกลับมาเป็น int บ้าง String บ้าง
// ขึ้นกับ driver และชนิด column — parse ให้ทนทั้งสองแบบ
int _toInt(dynamic value) {
  if (value is int) return value;
  return int.parse(value.toString());
}