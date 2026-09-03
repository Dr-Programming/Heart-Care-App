/// The authenticated patient, as the app understands them.
///
/// Deliberately free of JSON concerns — `UserModel` in the data layer handles
/// serialisation and maps into this (architectural rule 2: DTOs never leave
/// their feature's data layer).
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

  /// Always `PATIENT` in this build — the clinician role is out of scope.
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.name == name &&
          other.phone == phone &&
          other.preferredLanguage == preferredLanguage &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, name, phone, preferredLanguage, role);
}
