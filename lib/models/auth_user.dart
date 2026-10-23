class AuthUser {
  final int id;
  final String username;
  final String name;
  final String email;
  final String status;
  final String? role;
  final String? gender;

  const AuthUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.status,
    this.role,
    this.gender,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      username: json['username'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      status: json['status'] as String,
      role: json['role'] as String?,
      gender: json['gender'] as String?,
    );
  }

  String get firstName {
    final cleanName = name.trim();
    return cleanName.isEmpty ? username : cleanName.split(RegExp(r'\s+')).first;
  }

  String get greeting {
    final prefix = switch (gender?.trim().toLowerCase()) {
      'male' || 'hombre' || 'masculino' => 'Bienvenido',
      'female' || 'mujer' || 'femenino' => 'Bienvenida',
      _ => 'Hola',
    };
    return '$prefix $firstName';
  }
}
