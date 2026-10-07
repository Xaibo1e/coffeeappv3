import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coffeeappv3/services/api_client.dart';

// feature.md B2 (ปิด G5, G6) — ApiClient
//
// ทดสอบได้โดยไม่ต้องยิง HTTP จริงเพราะ ApiClient รับ http.Client เข้ามาทาง constructor
// (Dependency Injection) — เป็นเหตุผลเดียวกับที่ feature.md C6 เสนอให้ทำกับ Service
// ตัวอื่นด้วย ตอนนี้ได้มาฟรีกับทุก Service ที่ใช้ ApiClient
ApiClient _clientReturning(int statusCode, Object body) {
  return ApiClient(
    client: MockClient((request) async {
      return http.Response(
        jsonEncode(body),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  setUp(() {
    ApiClient.onUnauthorized = null;
  });

  tearDown(() {
    ApiClient.onUnauthorized = null;
  });

  group('ApiClient', () {
    test('returns the response as-is on 2xx', () async {
      final api = _clientReturning(200, {'status': 'ok', 'value': 1});

      final response = await api.get('http://localhost/api/products');

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body)['value'], 1);
    });

    test('accepts 201 Created, not only 200', () async {
      final api = _clientReturning(201, {'status': 'ok'});

      final response = await api.post('http://localhost/api/products');

      expect(response.statusCode, 201);
    });

    test('401 triggers onUnauthorized and throws UnauthorizedException', () async {
      var loggedOut = 0;
      ApiClient.onUnauthorized = () => loggedOut++;

      final api = _clientReturning(401, {
        'status': 'error',
        'message': 'Token expired',
      });

      await expectLater(
        api.get('http://localhost/api/products', token: 'stale-token'),
        throwsA(isA<UnauthorizedException>()),
      );

      // hook ต้องถูกเรียก ไม่ใช่แค่โยน exception เฉย ๆ — ไม่งั้นแอปจะค้างอยู่หน้าเดิม
      // พร้อม token ที่ใช้ไม่ได้แล้ว
      expect(loggedOut, 1);
    });

    test('401 carries the message from the server', () async {
      final api = _clientReturning(401, {
        'status': 'error',
        'message': 'Token expired',
      });

      try {
        await api.get('http://localhost/api/orders', token: 'stale-token');
        fail('should have thrown');
      } on UnauthorizedException catch (e) {
        expect(e.message, 'Token expired');
      }
    });

    // 403 ไม่ใช่เรื่องของ session — ผู้ใช้ Login อยู่จริงแต่ไม่มีสิทธิ์ทำสิ่งนั้น
    // (เช่น customer กดลบสินค้า) จึงต้องไม่ไปสั่ง logout
    test('403 does NOT log the user out', () async {
      var loggedOut = 0;
      ApiClient.onUnauthorized = () => loggedOut++;

      final api = _clientReturning(403, {
        'status': 'error',
        'message': 'Admin role required',
      });

      await expectLater(
        api.delete('http://localhost/api/products/1', token: 'customer-token'),
        throwsA(isA<ApiException>()),
      );

      expect(loggedOut, 0);
    });

    test('other errors throw ApiException with the status code', () async {
      final api = _clientReturning(400, {
        'status': 'error',
        'message': 'items is required',
      });

      try {
        await api.post('http://localhost/api/orders', token: 'token');
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'items is required');
      }
    });

    test('falls back to a generic message when the body is not JSON', () async {
      final api = ApiClient(
        client: MockClient((request) async => http.Response('<html>502</html>', 502)),
      );

      try {
        await api.get('http://localhost/api/products', token: 'token');
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.statusCode, 502);
        expect(e.message, contains('502'));
      }
    });
  });
}