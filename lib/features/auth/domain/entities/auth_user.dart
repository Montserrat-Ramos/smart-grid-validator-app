class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.isGuest = false,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isGuest;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        fullName: (json['name'] ?? json['fullName'] ?? json['full_name'] ?? 'Usuario').toString(),
        role: (json['role'] ?? 'ANALYST').toString().toUpperCase(),
        isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
        isGuest: json['guest'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': fullName,
        'role': role,
        'isActive': isActive,
        'guest': isGuest,
      };
}
