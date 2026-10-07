import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorite_provider.dart';

// planV2.md ข้อ 56 Session 5 ชั่วโมงที่ 1 — Flow:
// Start App -> Read Saved Token -> Token exists? -> Yes: Home / No: Login
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    final favorites = context.read<FavoriteProvider>();

    // feature.md A3 (ปิด G3): กู้ทั้งสามอย่างพร้อมกัน — ไม่ขึ้นต่อกันจึงรอขนานกันได้
    //
    // ราคาที่กู้มาอาจเก่า จะถูก sync กับ API อีกทีตอน HomeScreen โหลดสินค้าเสร็จ
    await Future.wait([
      auth.restoreSession(),
      cart.restore(),
      favorites.restore(),
    ]);

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      auth.isAuthenticated ? '/home' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.coffee,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}