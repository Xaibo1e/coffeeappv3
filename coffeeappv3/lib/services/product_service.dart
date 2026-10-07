import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import 'api_client.dart';

class ProductService {
  // feature.md B2: ไม่เรียก http โดยตรงอีกแล้ว — ApiClient ตรวจ status code และ
  // จัดการ 401 ให้ที่เดียว โค้ดในไฟล์นี้จึงเหลือแค่เรื่อง "แปลง JSON เป็น Product"
  final ApiClient apiClient;

  ProductService({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient();

  Future<List<Product>> getProducts(String token) async {
    final response = await apiClient.get(ApiConfig.products, token: token);

    final data = jsonDecode(response.body);

    // backend คืน Array ตรงๆ ไม่ห่อด้วย { products: [...] } (ดู backendapi.md ข้อ 2)
    final List list = data is List ? data : (data['products'] as List);

    return list
        .map((json) => Product.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Product> getProductById(String token, int id) async {
    final response = await apiClient.get(
      ApiConfig.productById(id),
      token: token,
    );

    // feature.md B3 (ปิด G7): backend คืน Object เดี่ยวแล้ว
    //
    // บรรทัด `data is List ? data.first : data` ที่เคยอยู่ตรงนี้ถูกลบออกได้จริง
    // หลังแก้ getProductById() ฝั่ง server ให้ส่ง results[0] — เป็นตัวอย่างที่เห็น
    // กับตาว่าการออกแบบ API ที่ดีทำให้โค้ด client สั้นลง
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // Challenge 5 (plan.md ข้อ 57 / planV2.md ข้อ 59) — Admin Product CRUD.
  // Backend รับ multipart/form-data เท่านั้นสำหรับ create/update (ใช้ multer,
  // field รูป = "photo" — ดู backendapi.md ข้อ 2) ไม่ใช่ JSON แบบ endpoint อื่น
  Future<Product> createProduct({
    required String token,
    required String name,
    String? description,
    required String barcode,
    required int stock,
    required int price,
    required int categoryId,
    XFile? imageFile,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.products))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['name'] = name
      ..fields['description'] = description ?? ''
      ..fields['barcode'] = barcode
      ..fields['stock'] = stock.toString()
      ..fields['price'] = price.toString()
      ..fields['category_id'] = categoryId.toString()
      // feature.md B1: ไม่ส่ง user_id อีกต่อไป — server อ่านเจ้าของจาก token เอง
      ..fields['status_id'] = '1';

    if (imageFile != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
        ),
      );
    }

    return _sendProductForm(request);
  }

  Future<Product> updateProduct({
    required String token,
    required int id,
    String? name,
    String? description,
    String? barcode,
    int? stock,
    int? price,
    int? categoryId,
    XFile? imageFile,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(ApiConfig.productById(id)),
    )..headers['Authorization'] = 'Bearer $token';

    if (name != null) request.fields['name'] = name;
    if (description != null) request.fields['description'] = description;
    if (barcode != null) request.fields['barcode'] = barcode;
    if (stock != null) request.fields['stock'] = stock.toString();
    if (price != null) request.fields['price'] = price.toString();
    if (categoryId != null) request.fields['category_id'] = categoryId.toString();

    if (imageFile != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
        ),
      );
    }

    return _sendProductForm(request);
  }

  Future<Product> _sendProductForm(http.MultipartRequest request) async {
    final response = await apiClient.send(request);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String token, int id) async {
    await apiClient.delete(ApiConfig.productById(id), token: token);
  }
}