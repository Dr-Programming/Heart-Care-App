/// Client-side validation for the auth screens.
///
/// Each method returns a translation key (never a rendered sentence) so the
/// widget layer decides how and when to localize it — see the M1 design
/// decision that validators return keys, not sentences.
abstract final class AuthValidators {
  static final RegExp _phone = RegExp(r'^\+251\d{9}$');
  static final RegExp _pin = RegExp(r'^\d{4}$');
  static const int _maxNameLength = 255;

  static String? phone(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'auth.errors.phoneRequired';
    if (!_phone.hasMatch(trimmed)) return 'auth.errors.phoneFormat';
    return null;
  }

  static String? pin(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'auth.errors.pinRequired';
    if (!_pin.hasMatch(trimmed)) return 'auth.errors.pinFormat';
    return null;
  }

  static String? confirmPin(String pinValue, String confirmValue) {
    final String? confirmError = pin(confirmValue);
    if (confirmError != null) return confirmError;
    if (pinValue.trim() != confirmValue.trim()) {
      return 'auth.errors.pinMismatch';
    }
    return null;
  }

  static String? name(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > _maxNameLength) {
      return 'auth.errors.nameRequired';
    }
    return null;
  }
}
