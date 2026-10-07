import 'dart:convert';
import 'package:http/http.dart' as http;

/// โยนเมื่อ Backend ตอบ 401 — แปลว่า session ใช้ไม่ได้แล้ว ไม่ใช่ว่า request ผิด
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

/// โยนเมื่อ Backend ตอบ status code อื่นที่ไม่ใช่ 2xx
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

// feature.md B2 (ปิด G5, G6) — รวม error handling ไว้ที่เดียว
//
// ก่อนหน้านี้ทุก Service ต้องเขียนโค้ดตรวจ error ของตัวเอง ซึ่งแปลว่าถ้าจะเพิ่ม
// "เจอ 401 แล้วให้ logout อัตโนมัติ" ต้องไปแก้ทุกไฟล์ และลืมไฟล์เดียวก็มีจุดที่แอป
// ค้างหน้าขาวได้ — ย้ายมารวมไว้ที่นี่ที่เดียว เพิ่มกฎใหม่ทีหลังก็แก้จุดเดียว
//
// ⚠️ AuthService **ไม่ได้** ใช้คลาสนี้โดยตั้งใจ เพราะ 401 จากหน้า Login แปลว่า
// "รหัสผ่านผิด" ไม่ใช่ "session หมดอายุ" — ถ้าปล่อยให้ผ่านตรงนี้ การพิมพ์รหัสผิด
// จะไปสั่ง logout ซ้ำซ้อนทุกครั้ง ต้องแยกสองเรื่องนี้ออกจากกันให้ชัด
class ApiClient {
  /// ถูกเรียกทุกครั้งที่เจอ 401 จาก endpoint ที่ต้องใช้ token
  ///
  /// ตั้งค่าครั้งเดียวตอนแอปเริ่มทำงาน (ดู main.dart) — ใช้ static เพราะ Service
  /// แต่ละตัวสร้าง ApiClient ของตัวเอง แต่กฎ "เจอ 401 แล้วทำอะไร" ต้องเป็นตัวเดียวกัน
  /// ทั้งแอป
  static void Function()? onUnauthorized;

  final http.Client _client;

  // รับ http.Client เข้ามาได้เพื่อให้เขียน test ได้โดยไม่ต้องยิง HTTP จริง
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String? token, {bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> get(String url, {String? token}) async {
    return _check(await _client.get(Uri.parse(url), headers: _headers(token)));
  }

  Future<http.Response> post(
    String url, {
    String? token,
    Object? body,
  }) async {
    return _check(await _client.post(
      Uri.parse(url),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    ));
  }

  Future<http.Response> delete(String url, {String? token}) async {
    return _check(
      await _client.delete(Uri.parse(url), headers: _headers(token, json: false)),
    );
  }

  /// สำหรับ multipart/form-data (อัปโหลดรูปสินค้า) ซึ่งประกอบ request เองไม่ได้
  /// ผ่าน method ข้างบน
  Future<http.Response> send(http.MultipartRequest request) async {
    final streamed = await _client.send(request);
    return _check(await http.Response.fromStream(streamed));
  }

  http.Response _check(http.Response response) {
    if (response.statusCode == 401) {
      // เรียก hook ก่อนโยน เพื่อให้แอปเริ่มพากลับหน้า Login ทันที ไม่ต้องรอให้
      // ทุก Service ที่กำลังค้างอยู่ทยอย catch จนครบ
      onUnauthorized?.call();
      throw UnauthorizedException(
        _messageOf(response) ?? 'Session expired, please log in again',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _messageOf(response) ?? 'Request failed (${response.statusCode})',
      );
    }

    return response;
  }

  // Backend ตอบ { status, message } เป็นมาตรฐาน — ดึงข้อความจริงมาแสดงให้ผู้ใช้
  // ถ้าอ่านไม่ได้ (เช่น proxy ตอบ HTML มา) ก็ปล่อยให้ผู้เรียกใช้ข้อความสำรอง
  String? _messageOf(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {
      // ตั้งใจกลืน — ไม่ควรให้ error ตอน parse มาบดบัง error ตัวจริงที่กำลังรายงาน
    }
    return null;
  }
}