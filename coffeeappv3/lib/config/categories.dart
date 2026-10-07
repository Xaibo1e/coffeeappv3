/// Backend ไม่มีตาราง `categories` จริง — `category_id` เป็นแค่ column ตัวเลข
/// (ดู backendapi.md ข้อ 3) จึง hardcode ชื่อหมวดหมู่ไว้ที่นี่ตามที่ seed ไว้ใน
/// serverapi/seeds/products.ts: 1 = Coffee, 2 = Non-Coffee, 3 = Bakery
class ProductCategory {
  static const Map<int, String> names = {
    1: 'Coffee',
    2: 'Non-Coffee',
    3: 'Bakery',
  };
}