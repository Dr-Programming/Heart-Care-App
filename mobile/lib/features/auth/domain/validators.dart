
final RegExp _phonePattern = RegExp(r'^\+251\d{9}$');
final RegExp _pinPattern = RegExp(r'^\d{4}$');

String? validatePhone(String value) {
  if (value.trim().isEmpty) return 'auth.errors.phoneRequired';
  if (!_phonePattern.hasMatch(value.trim())) return 'auth.errors.phoneFormat';
  return null;
}

String? validatePin(String value) {
  if (value.isEmpty) return 'auth.errors.pinRequired';
  if (!_pinPattern.hasMatch(value)) return 'auth.errors.pinFormat';
  return null;
}

String? validateName(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 255) return 'auth.errors.nameRequired';
  return null;
}
