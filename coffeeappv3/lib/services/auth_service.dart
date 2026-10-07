import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// feature.md B2: ไฟล์นี้ **ไม่ได้** ใช้ ApiClient โดยตั้งใจ
//
// ApiClient ถือกฎว่า "เจอ 401 = session หมดอายุ ให้ logout" ซึ่งถูกต้องสำหรับ endpoint
// ที่ต้องใช้ token แต่ 401 ที่ออกมาจากหน้า Login แปลว่า "รหัสผ่านผิด" คนละเรื่องกัน
// ถ้าใช้ตัวเดียวกัน การพิมพ์รหัสผิดจะไปสั่ง logout ทุกครั้งโดยไม่มีเหตุผล
class AuthService {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _post(
      url: ApiConfig.login,
      body: {
        'email': email,
        'password': password,
      },
      fallbackErrorMessage: 'Login failed',
    );
  }

  // feature.md A1 (ปิด G1): endpoint นี้มีอยู่ใน backend ตั้งแต่ต้นฉบับแล้ว
  // (serverapi/routes/authRoutes.ts) แต่ไม่เคยมี UI ฝั่ง Flutter เรียกใช้
  //
  // Backend ตอบหน้าตาเดียวกับ login ทุกประการ — { status, message, token, user }
  // จึงนำ session ไปใช้ต่อได้ทันทีโดยไม่ต้องให้ผู้ใช้ Login ซ้ำ
  Future<Map<String, dynamic>> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    return _post(
      url: ApiConfig.register,
      body: {
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'password': password,
      },
      fallbackErrorMessage: 'Register failed',
    );
  }

  // ส่วนที่ login กับ register ใช้ร่วมกัน — แยกออกมาเพื่อไม่ต้องคัดลอกกฎการอ่าน
  // error ของ backend ไปไว้ทุก method (endpoint ตัวที่สามจะได้ใช้ต่อได้ทันที)
  Future<Map<String, dynamic>> _post({
    required String url,
    required Map<String, dynamic> body,
    required String fallbackErrorMessage,
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // feature.md B3 (ปิด G6): เช็ค statusCode ได้ตรงไปตรงมาแล้ว
    //
    // เดิม backend ตอบ HTTP 200 เสมอไม่ว่าสำเร็จหรือผิดพลาด โค้ดตรงนี้จึงต้องอ่าน
    // field `status` ในตัว body แทน ตอนนี้ Login ที่รหัสผิดได้ 401 และสมัครด้วย
    // email ซ้ำได้ 409 ตามมาตรฐาน REST จริง ๆ
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? fallbackErrorMessage,
    );
  }
}