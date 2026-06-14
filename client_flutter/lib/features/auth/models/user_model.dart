class UserModel {
  final String id;
  final String username;
  final String email;
  final String? phone;
  final String role;
  final bool active;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
    required this.active,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      active: json['active'] is bool 
          ? json['active'] as bool 
          : (json['active'] == 1 || json['active'] == true),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
      'active': active ? 1 : 0,
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}
