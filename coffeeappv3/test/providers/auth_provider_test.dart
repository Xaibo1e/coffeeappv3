import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffeeappv3/providers/auth_provider.dart';
import 'package:coffeeappv3/services/auth_service.dart';

// สร้าง JWT ปลอมที่มีโครงสร้าง 3 ส่วนถูกต้อง (header.payload.signature) แต่ลายเซ็นมั่ว
//
// จำเป็นตั้งแต่ feature.md รอบ 0 เป็นต้นไป เพราะ AuthProvider.restoreSession() อ่าน
// payload เพื่อตรวจว่า token เป็นรุ่นที่มี id หรือไม่ — string สั้น ๆ อย่าง 'fake-jwt-token'
// จึงใช้ไม่ได้อีกแล้ว ลายเซ็นไม่ต้องถูกเพราะฝั่ง client ไม่เคยตรวจ (server ตรวจให้)
String fakeJwt(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');

  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  return '$header.${segment(payload)}.not-a-real-signature';
}

// Fake ที่ extend ของจริงเพื่อตัด HTTP ออก — plan.md ข้อ 47/48 (Login Success/Failure)
class _FakeAuthService extends AuthService {
  final bool shouldSucceed;
  final String role;

  // feature.md A1: จำลองกรณี email ซ้ำ ซึ่งเป็น error ที่ตรวจได้ที่ server เท่านั้น
  final bool emailAlreadyExists;

  _FakeAuthService({
    this.shouldSucceed = true,
    this.role = 'customer',
    this.emailAlreadyExists = false,
  });

  @override
  Future<Map<String, dynamic>> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    // AuthService.register() แปลง {"status":"error"} ที่ backend ส่งมาเป็น Exception
    // ก่อนถึง Provider เสมอ — fake จึงโยน Exception เหมือนกันเพื่อให้ทดสอบตรงกับของจริง
    if (emailAlreadyExists) {
      throw Exception('Email already exists');
    }

    return {
      'token': fakeJwt({'id': 2, 'email': email, 'role': 'customer'}),
      'user': {
        'id': 2,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'role': 'customer',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      return {
        'token': fakeJwt({'id': 1, 'email': email, 'role': role}),
        'user': {
          'id': 1,
          'firstname': 'Coffee',
          'lastname': 'Student',
          'email': email,
          'role': role,
        },
      };
    }
    throw Exception('Email and password does not match');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthProvider', () {
    test('login success stores token/user and clears error (Demo 1)', () async {
      final auth = AuthProvider(authService: _FakeAuthService());

      final result = await auth.login('student@example.com', '123456');

      expect(result, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.token, isNotNull);
      expect(auth.user?.role, 'customer');
      expect(auth.user?.isAdmin, isFalse);
      expect(auth.user?.email, 'student@example.com');
      expect(auth.errorMessage, isNull);
      expect(auth.isLoading, isFalse);
    });

    test('login failure sets errorMessage and stays unauthenticated (Demo 2)', () async {
      final auth = AuthProvider(authService: _FakeAuthService(shouldSucceed: false));

      final result = await auth.login('student@example.com', 'wrong-password');

      expect(result, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('does not match'));
    });

    test('logout clears token and user', () async {
      final auth = AuthProvider(authService: _FakeAuthService());
      await auth.login('student@example.com', '123456');

      auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.token, isNull);
      expect(auth.user, isNull);
    });

    // planV2.md ข้อ 56 Session 5 ชั่วโมงที่ 1: Persist Login / Auto Login
    test('restoreSession restores a session saved by a previous login', () async {
      final loggedIn = AuthProvider(authService: _FakeAuthService());
      await loggedIn.login('student@example.com', '123456');

      // ตัวแทน Provider ใหม่ที่ถูกสร้างตอนเปิดแอปใหม่ (cold start)
      final restored = AuthProvider(authService: _FakeAuthService());
      await restored.restoreSession();

      expect(restored.isAuthenticated, isTrue);
      expect(restored.token, loggedIn.token);
      expect(restored.user?.email, 'student@example.com');
    });

    test('restoreSession stays unauthenticated when nothing was saved', () async {
      final auth = AuthProvider(authService: _FakeAuthService());

      await auth.restoreSession();

      expect(auth.isAuthenticated, isFalse);
    });

    // planV2.md ข้อ 57 Session 6 Test Cases: "Logout แล้วเปิดแอปใหม่"
    test('logout removes the persisted session so restoreSession finds nothing', () async {
      final loggedIn = AuthProvider(authService: _FakeAuthService());
      await loggedIn.login('student@example.com', '123456');

      loggedIn.logout();
      // logout() ลบ session แบบ fire-and-forget (ไม่ await ภายใน) — รอ microtask
      // ให้ _clearSession() ทำงานจบก่อนตรวจสอบ
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final restored = AuthProvider(authService: _FakeAuthService());
      await restored.restoreSession();

      expect(restored.isAuthenticated, isFalse);
    });

    // feature.md รอบ 0 — Breaking change ของ JWT payload
    test('restoreSession discards a legacy token that has no user id', () async {
      // จำลอง session ที่บันทึกไว้ตอน backend ยัง sign ด้วย { email } เท่านั้น
      SharedPreferences.setMockInitialValues({
        'auth_token': fakeJwt({'email': 'student@example.com'}),
        'auth_user': jsonEncode({
          'id': 1,
          'firstname': 'Coffee',
          'lastname': 'Student',
          'email': 'student@example.com',
        }),
      });

      final auth = AuthProvider(authService: _FakeAuthService());
      await auth.restoreSession();

      expect(auth.isAuthenticated, isFalse);

      // ต้องลบทิ้งจริง ไม่ใช่แค่ไม่โหลด — ไม่งั้นเปิดแอปรอบถัดไปก็เจอปัญหาเดิม
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });

    // feature.md A1 (ปิด G1) — Register
    test('register stores the session so no second login is needed', () async {
      final auth = AuthProvider(authService: _FakeAuthService());

      final result = await auth.register(
        firstname: 'New',
        lastname: 'Student',
        email: 'new@example.com',
        password: '123456',
      );

      expect(result, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.email, 'new@example.com');
      expect(auth.user?.isAdmin, isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.isLoading, isFalse);

      // ต้องบันทึกลง SharedPreferences ด้วย ไม่ใช่เก็บแค่ในหน่วยความจำ
      // ไม่งั้นปิดแอปแล้วเปิดใหม่จะต้อง Login ทั้งที่เพิ่งสมัครไป
      final restored = AuthProvider(authService: _FakeAuthService());
      await restored.restoreSession();
      expect(restored.isAuthenticated, isTrue);
    });

    test('register with a duplicate email shows an error and saves nothing', () async {
      final auth = AuthProvider(
        authService: _FakeAuthService(emailAlreadyExists: true),
      );

      final result = await auth.register(
        firstname: 'New',
        lastname: 'Student',
        email: 'student@example.com',
        password: '123456',
      );

      expect(result, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, 'Email already exists');
      expect(auth.isLoading, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });

    test('admin role survives login and restoreSession', () async {
      final loggedIn = AuthProvider(authService: _FakeAuthService(role: 'admin'));
      await loggedIn.login('admin@example.com', '123456');

      expect(loggedIn.user?.isAdmin, isTrue);

      final restored = AuthProvider(authService: _FakeAuthService());
      await restored.restoreSession();

      expect(restored.user?.isAdmin, isTrue);
    });
  });
}