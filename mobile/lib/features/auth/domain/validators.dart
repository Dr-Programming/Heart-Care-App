/// Client-side mirrors of the server's validation rules.
///
/// Each returns a **translation key** or null, so the UI stays responsible for
/// rendering language. Keeping these in sync with the backend matters: the
/// server enforces the same regexes and would answer 400, but on intermittent
/// connectivity a wasted round trip can cost the user a minute.
abstract final class AuthValidators {
  static final RegExp _phone = RegExp(r'^\+251\d{9}$');
  static final RegExp _pin = RegExp(r'^\d{4}$');
  static const int _maxNameLength = 255;

  static String? phone(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'errors.phoneRequired';
    return _phone.hasMatch(v) ? null : 'errors.phoneFormat';
  }

  static String? pin(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'errors.pinRequired';
    return _pin.hasMatch(v) ? null : 'errors.pinFormat';
  }

  static String? confirmPin(String? pinValue, String? confirmValue) {
    final String? base = pin(confirmValue);
    if (base != null) return base;
    return (pinValue ?? '').trim() == (confirmValue ?? '').trim()
        ? null
        : 'errors.pinMismatch';
  }

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty || v.length > _maxNameLength) return 'errors.nameRequired';
    return null;
  }
}
