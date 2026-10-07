import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coffeeappv3/services/api_client.dart';
import 'package:coffeeappv3/services/product_service.dart';

// feature.md B3 (ปิด G7) — พิสูจน์ว่าโค้ด workaround ฝั่ง client ถูกลบออกได้จริง
//
// เดิม getProductById() ต้องมีบรรทัด `data is List ? data.first : data` เพราะ backend
// คืน Array เสมอแม้ query ด้วย id เดียว หลังแก้ที่ต้นเหตุ endpoint คืน Object เดี่ยว
// แล้ว test นี้จึงล็อกไว้ว่าฝั่ง client อ่าน Object ตรง ๆ ได้
ProductService _serviceReturning(int statusCode, Object body) {
  return ProductService(
    apiClient: ApiClient(
      client: MockClient((request) async => http.Response(
            jsonEncode(body),
            statusCode,
            headers: {'content-type': 'application/json'},
          )),
    ),
  );
}

void main() {
  setUp(() {
    ApiClient.onUnauthorized = null;
  });

  group('ProductService', () {
    test('getProductById parses a single object, not an array', () async {
      final service = _serviceReturning(200, {
        'id': 3,
        'name': 'Cappuccino',
        'description': 'Espresso with steamed milk',
        'image': 'cappuccino.jpg',
        'stock': 12,
        'price': 65,
        'category_id': 1,
      });

      final product = await service.getProductById('token', 3);

      expect(product.id, 3);
      expect(product.name, 'Cappuccino');
      expect(product.price, 65);
      expect(product.categoryId, 1);
    });

    test('getProductById surfaces 404 as an ApiException', () async {
      final service = _serviceReturning(404, {
        'status': 'error',
        'message': 'Product not found',
      });

      await expectLater(
        service.getProductById('token', 999),
        throwsA(isA<ApiException>()),
      );
    });

    test('getProducts parses the raw array the list endpoint returns', () async {
      final service = _serviceReturning(200, [
        {
          'id': 1,
          'name': 'Americano',
          'stock': 20,
          'price': 55,
          'category_id': 1,
        },
        {
          'id': 2,
          'name': 'Latte',
          'stock': 15,
          'price': 65,
          'category_id': 1,
        },
      ]);

      final products = await service.getProducts('token');

      expect(products.length, 2);
      expect(products.first.name, 'Americano');
    });

    test('a 401 from a product call logs the user out', () async {
      var loggedOut = 0;
      ApiClient.onUnauthorized = () => loggedOut++;

      final service = _serviceReturning(401, {
        'status': 'error',
        'message': 'Token expired',
      });

      await expectLater(
        service.getProducts('stale-token'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(loggedOut, 1);
    });
  });
}