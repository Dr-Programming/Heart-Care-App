

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.preferredLanguage,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;

  final String preferredLanguage;
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          preferredLanguage == other.preferredLanguage &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, phone, preferredLanguage, role);
}
