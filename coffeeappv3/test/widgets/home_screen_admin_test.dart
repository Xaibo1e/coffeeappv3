import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffeeappv3/models/product.dart';
import 'package:coffeeappv3/providers/auth_provider.dart';
import 'package:coffeeappv3/providers/cart_provider.dart';
import 'package:coffeeappv3/providers/favorite_provider.dart';
import 'package:coffeeappv3/providers/product_provider.dart';
import 'package:coffeeappv3/screens/home_screen.dart';
import 'package:coffeeappv3/services/auth_service.dart';
import 'package:coffeeappv3/services/product_service.dart';

// feature.md B1 (ปิด G4): ปุ่ม Admin ต้องโผล่เฉพาะ user ที่ role = 'admin'
//
// ⚠️ test ชุดนี้ยืนยันได้แค่เรื่อง UI เท่านั้น การกันสิทธิ์จริงอยู่ที่ requireAdmin
// ฝั่ง server ซึ่งต้องพิสูจน์ด้วย curl (ดูบทเรียน role-permission)

class _FakeProductService extends ProductService {
  @override
  Future<List<Product>> getProducts(String token) async => const [];
}

class _FakeAuthService extends AuthService {
  final String role;
  _FakeAuthService(this.role);

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    String segment(Map<String, dynamic> map) =>
        base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');

    final header = segment({'alg': 'HS256', 'typ': 'JWT'});
    final payload = segment({'id': 1, 'email': email, 'role': role});

    return {
      'token': '$header.$payload.not-a-real-signature',
      'user': {
        'id': 1,
        'firstname': 'Coffee',
        'lastname': 'Tester',
        'email': email,
        'role': role,
      },
    };
  }
}

Future<Widget> _appFor(String role) async {
  final auth = AuthProvider(authService: _FakeAuthService(role));
  await auth.login('tester@example.com', '123456');

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(
        create: (_) => ProductProvider(productService: _FakeProductService()),
      ),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => FavoriteProvider()),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('customer does not see the Manage Products button', (tester) async {
    await tester.pumpWidget(await _appFor('customer'));
    await tester.pump();

    expect(find.byTooltip('Manage Products'), findsNothing);
    // ปุ่มอื่นบน AppBar ต้องยังอยู่ครบ — ซ่อนเฉพาะของ admin เท่านั้น
    expect(find.byTooltip('Cart'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);
  });

  testWidgets('admin sees the Manage Products button', (tester) async {
    await tester.pumpWidget(await _appFor('admin'));
    await tester.pump();

    expect(find.byTooltip('Manage Products'), findsOneWidget);
  });
}