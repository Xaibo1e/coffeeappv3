class Product {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final int stock;
  final int price;
  final int categoryId;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.image,
    required this.stock,
    required this.price,
    required this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _toInt(json['id']),
      name: json['name'] ?? '',
      description: json['description'],
      image: json['image'],
      stock: _toInt(json['stock']),
      price: _toInt(json['price']),
      categoryId: _toInt(json['category_id']),
    );
  }

  // feature.md A3 (ปิด G3): ต้องมี toJson() เพื่อเก็บ Cart/Favorite ลง
  // SharedPreferences — key ต้องตรงกับที่ fromJson() อ่าน (โดยเฉพาะ `category_id`
  // ที่เป็น snake_case ตาม backend ไม่ใช่ `categoryId` แบบชื่อ field ใน Dart)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image': image,
        'stock': stock,
        'price': price,
        'category_id': categoryId,
      };

  // backend คืนตัวเลขเป็น int ปกติตอน GET แต่คืนเป็น String ตอน POST/PUT
  // (เพราะรับค่าจาก multipart/form-data) — parse ให้ทนทั้งสองแบบ
  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.parse(value.toString());
  }
}