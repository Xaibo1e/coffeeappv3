import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final AuthService authService;

  String? token;
  User? user;

  bool isLoading = false;
  String? errorMessage;

  AuthProvider({
    required this.authService,
  });

  bool get isAuthenticated => token != null;

  // planV2.md ข้อ 56 Session 5 ชั่วโมงที่ 1: อ่าน Token ที่เคยบันทึกไว้ตอนเปิดแอป
  // เพื่อ Auto Login — ต้องเรียกครั้งเดียวตอน App เริ่มทำงาน (ดู SplashScreen)
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    final savedUserJson = prefs.getString(_userKey);

    if (savedToken != null && savedUserJson != null) {
      // feature.md A2/B1: backend เปลี่ยนมา sign JWT เป็น { id, email, role } แล้ว
      // token รุ่นเก่าที่มีแค่ { email } ยังผ่าน authenticateToken ได้ (ลายเซ็นถูกต้อง)
      // แต่จะพังตอนเรียก Order API เพราะ server หา user id ไม่เจอ — ตัดจบตั้งแต่ตอน
      // เปิดแอปด้วยการล้าง session ทิ้ง ให้ผู้ใช้ Login ใหม่หนึ่งครั้ง ดีกว่าปล่อยให้
      // ไปพังกลางทางตอนกดสั่งซื้อ
      if (!_tokenHasUserId(savedToken)) {
        await _clearSession();
        return;
      }

      token = savedToken;
      user = User.fromJson(
        jsonDecode(savedUserJson) as Map<String, dynamic>,
      );
      notifyListeners();
    }
  }

  // อ่าน payload ของ JWT โดยไม่ตรวจลายเซ็น — ใช้ตัดสินได้แค่ว่า token เป็นรุ่นเก่าหรือใหม่
  // เท่านั้น ห้ามใช้ตัดสินสิทธิ์ เพราะใครก็แก้ payload ฝั่ง client ได้ การตรวจสิทธิ์จริง
  // ต้องทำที่ server ที่มี JWT_SECRET เสมอ (ดู middleware/requireAdmin.ts)
  static bool _tokenHasUserId(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      return payload['id'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(
    String email,
    String password,
  ) async {
    return _authenticate(
      () => authService.login(
        email: email,
        password: password,
      ),
    );
  }

  // feature.md A1 (ปิด G1): สมัครเสร็จแล้วเข้าใช้งานได้เลย ไม่ต้อง Login ซ้ำ
  // เพราะ backend คืน token มาพร้อมกับผลการสมัครอยู่แล้ว
  Future<bool> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    return _authenticate(
      () => authService.register(
        firstname: firstname,
        lastname: lastname,
        email: email,
        password: password,
      ),
    );
  }

  // login กับ register ต่างกันแค่ "เรียก Service ตัวไหน" ส่วนที่เหลือ — ตั้ง isLoading,
  // ล้าง error, เก็บ token/user, บันทึก session, จัดการ error — เหมือนกันทุกบรรทัด
  Future<bool> _authenticate(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await request();

      token = data['token'];
      user = User.fromJson(data['user']);

      await _saveSession();

      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_userKey, jsonEncode(user!.toJson()));
  }

  void logout() {
    token = null;
    user = null;
    notifyListeners();
    _clearSession();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}