/// The signed-in patient, as the auth feature and its screens see them.
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
}
