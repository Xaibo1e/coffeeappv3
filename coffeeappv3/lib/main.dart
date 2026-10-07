import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'screens/admin_product_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/favorite_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/product_service.dart';

void main() {
  runApp(const MyApp());
}

// feature.md B2: ต้องเข้าถึง Navigator จากนอก widget tree ได้
//
// เพราะ 401 เกิดขึ้นได้จากทุกที่ — รวมถึงจังหวะที่ไม่มี BuildContext ให้ใช้ เช่น
// request ที่ยังค้างอยู่ตอนผู้ใช้เพิ่งเปลี่ยนหน้า
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// StatefulWidget เพื่อให้สร้าง AuthProvider ไว้ก่อนแล้วผูกเข้ากับ ApiClient ได้
// (ถ้าใช้ create: ของ MultiProvider เฉย ๆ Provider จะถูกสร้างแบบ lazy ตอนมีคนอ่าน
// ครั้งแรก ซึ่งอาจช้ากว่า request ตัวแรกที่ได้ 401 กลับมา)
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;

  // กันการเด้งซ้ำเมื่อหลาย request ตอบ 401 กลับมาพร้อมกัน (เช่น หน้า Home ที่ยิงทั้ง
  // โหลดสินค้าและโหลดประวัติพร้อมกัน) — ถ้าไม่กัน จะ push หน้า Login ซ้อนกันหลายชั้น
  bool _handlingUnauthorized = false;

  @override
  void initState() {
    super.initState();

    _authProvider = AuthProvider(authService: AuthService());

    // feature.md B2 (ปิด G5): เจอ 401 ที่ไหนก็ตามในแอป ให้พากลับหน้า Login
    //
    // นี่คือผลตอบแทนของการรวม error handling ไว้ใน ApiClient ที่เดียว — กฎข้อนี้
    // เขียนครั้งเดียวแล้วมีผลกับทุก Service ทันที ไม่ต้องไล่แก้ทีละไฟล์
    ApiClient.onUnauthorized = _handleUnauthorized;
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  void _handleUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;

    _authProvider.logout();

    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );

    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Session expired, please log in again'),
        duration: Duration(seconds: 3),
      ),
    );

    // ปลดล็อกหลัง frame นี้ เพื่อให้ session ถัดไปที่หมดอายุยังเด้งได้ตามปกติ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlingUnauthorized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productService: ProductService()),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoriteProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderService: OrderService()),
        ),
      ],
      child: MaterialApp(
        title: 'Campus Coffee',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
          useMaterial3: true,
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/cart': (context) => const CartScreen(),
          '/admin': (context) => const AdminProductListScreen(),
          '/favorites': (context) => const FavoriteScreen(),
          '/orders': (context) => const OrderHistoryScreen(),
        },
      ),
    );
  }
}