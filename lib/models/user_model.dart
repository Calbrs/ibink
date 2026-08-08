class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? token;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        token: j['token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email,
        'phone': phone, 'token': token,
      };
}
