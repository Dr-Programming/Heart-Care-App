import 'dart:convert';

/// Reads the `exp` claim without verifying the signature.
///
/// Verification is the server's job — this only exists so the auth gate can
/// avoid routing a user to Home with a token the server will reject. Anything
/// unreadable counts as expired: failing closed sends the user to Login, which
/// is recoverable, while failing open strands them on a broken Home screen.
bool isJwtExpired(String token, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now().toUtc();

  final List<String> parts = token.split('.');
  if (parts.length != 3) return true;

  try {
    final String normalised = base64Url.normalize(parts[1]);
    final Object? decoded = jsonDecode(
      utf8.decode(base64Url.decode(normalised)),
    );
    if (decoded is! Map<String, dynamic>) return true;

    final Object? exp = decoded['exp'];
    if (exp is! int) return true;

    final DateTime expiry = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return !expiry.isAfter(reference);
  } on Object {
    return true;
  }
}
