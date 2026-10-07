import 'package:flutter/foundation.dart';

/// Base URL ของ Backend API
///
/// plan.md ข้อ 14 สอนว่า Android Emulator ต้องใช้ `10.0.2.2` แทน `localhost`
/// เพราะ Emulator มองเครื่องพัฒนาเป็นเครื่องอื่นในเครือข่ายเสมือน
///
/// ไฟล์นี้ตรวจ platform อัตโนมัติเพื่อให้รันได้ทั้ง Web (ใช้ทดสอบบนเครื่องพัฒนานี้
/// ที่ไม่มี Android Emulator) และ Android Emulator (ตามที่ plan.md สอน) โดยไม่ต้อง
/// แก้โค้ดเอง — แต่แนวคิดเรื่อง `10.0.2.2` ยังคงสำคัญและต้องอธิบายให้นักศึกษาฟัง
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static String get login => '$baseUrl/api/auth/login';
  static String get register => '$baseUrl/api/auth/register';
  static String get products => '$baseUrl/api/products';
  static String productById(int id) => '$baseUrl/api/products/$id';

  // feature.md A2 — Order API
  static String get orders => '$baseUrl/api/orders';
  static String orderById(int id) => '$baseUrl/api/orders/$id';

  /// ประกอบ URL เต็มของรูปสินค้าจากชื่อไฟล์ที่ backend คืนมา (field `image`)
  /// backend เก็บแค่ชื่อไฟล์ ไม่ใช่ URL เต็ม — ดู backendapi.md ข้อ 8 ขั้นที่ 5
  static String imageUrl(String? filename) {
    if (filename == null || filename.isEmpty) return '';
    return '$baseUrl/uploads/images/$filename';
  }
}