import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  int get subtotal => product.price * quantity;

  // feature.md A3 (ปิด G3): serialize object ที่มี object ซ้อนอยู่ข้างใน
  //
  // ต่างจาก User.toJson() ที่ทุก field เป็นค่าพื้นฐาน — ตรงนี้ต้องเรียก
  // product.toJson() ต่ออีกชั้น และตอนอ่านกลับก็ต้อง Product.fromJson() ก่อน
  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
    );
  }

  /// สร้างชุดใหม่โดยใช้ข้อมูลสินค้าล่าสุดจาก API แทนของที่เก็บไว้
  ///
  /// ตอบคำถามออกแบบที่สำคัญของ Feature นี้ — _ถ้าราคาสินค้าเปลี่ยนหลังจากเก็บ Cart
  /// ไว้ ควรใช้ราคาไหน?_ คำตอบคือราคาปัจจุบัน เพราะตะกร้ายังไม่ใช่การซื้อ ผู้ใช้ยัง
  /// ไม่ได้จ่ายเงิน (ต่างจาก order_items ที่ต้อง Snapshot ไว้ เพราะจ่ายไปแล้ว)
  CartItem withProduct(Product latest) => CartItem(
        product: latest,
        // ถ้าของเหลือน้อยลงกว่าที่เคยใส่ไว้ ต้องลดจำนวนลงตาม ไม่ปล่อยให้เกิน stock
        quantity: quantity > latest.stock ? latest.stock : quantity,
      );
}