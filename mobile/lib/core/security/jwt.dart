import 'dart:convert';

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
