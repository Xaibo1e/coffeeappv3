class User {
  final int id;
  final String firstname;
  final String lastname;
  final String email;

  // feature.md B1 (ปิด G4): backend เก็บ role ไว้ในตาราง users และใส่มาใน JWT
  // ค่าที่เป็นไปได้คือ 'customer' กับ 'admin' ตาม migration add_role_to_users
  final String role;

  User({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    this.role = 'customer',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.parse(json['id'].toString()),
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      email: json['email'] ?? '',
      // default เป็น customer เมื่อไม่มี field นี้ — เกิดได้ 2 กรณี: session เก่าที่
      // บันทึกไว้ใน SharedPreferences ก่อนมี role และ backend ที่ยังไม่ได้ migrate
      // เลือกฝั่งที่ปลอดภัยกว่าเสมอ (สิทธิ์น้อยสุด) ไม่ใช่ปล่อยให้เป็น admin
      role: json['role']?.toString() ?? 'customer',
    );
  }

  String get fullName => '$firstname $lastname';

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'role': role,
      };
}