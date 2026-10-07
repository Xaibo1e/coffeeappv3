import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coffeeappv3/providers/auth_provider.dart';
import 'package:coffeeappv3/screens/login_screen.dart';
import 'package:coffeeappv3/services/auth_service.dart';

class _FailingAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    throw Exception('Email and password does not match');
  }
}

void main() {
  // plan.md ข้อ 48 (Demo 2 — Login Failure): กด LOGIN แล้ว UI ต้องแสดง
  // errorMessage จาก AuthProvider ให้ผู้ใช้เห็น
  testWidgets('shows the AuthProvider error message after a failed login', (tester) async {
    final auth = AuthProvider(authService: _FailingAuthService());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Email and password does not match'), findsNothing);

    // เรียก onPressed ตรง ๆ แทน tester.tap() โดยตั้งใจ
    //
    // tester.tap() จะจุด ink splash ของ Material ซึ่งต้องโหลด shader
    // `shaders/ink_sparkle.frag` — บน Flutter 3.44 บางเครื่อง shader นี้โหลดไม่ผ่าน
    // แล้วทำให้ test ล้มด้วยเหตุที่ไม่เกี่ยวกับสิ่งที่กำลังทดสอบเลย การเรียก callback
    // ตรงทดสอบพฤติกรรมเดียวกันได้โดยไม่ต้องพึ่ง rendering pipeline
    final loginButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'LOGIN'),
    );
    loginButton.onPressed!();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Email and password does not match'), findsOneWidget);
  });

  testWidgets('email/password fields are prefilled with the demo user', (tester) async {
    final auth = AuthProvider(authService: _FailingAuthService());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('student@example.com'), findsOneWidget);
  });
}