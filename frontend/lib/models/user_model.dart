class UserModel {
  final String id;
  final String username;
  final String? name;
  final String? email;
  final String role;
  final String token;

  const UserModel({
    required this.id,
    required this.username,
    this.name,
    this.email,
    this.role = 'user',
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? json['sub']?.toString() ?? 'user-default-id',
      username: json['username']?.toString() ?? json['name']?.toString() ?? 'Agent',
      name: json['name']?.toString() ?? json['username']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'teacher',
      token: token ?? json['access_token']?.toString() ?? json['token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? role,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }
}
