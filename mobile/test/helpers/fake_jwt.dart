import 'dart:convert';

/// A syntactically valid JWT with the given expiry — enough for
/// `core/security/jwt.dart`'s `isJwtExpired` to parse, since it never checks
/// the signature.
String fakeJwt({required DateTime expiresAt}) {
  final int expSeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
  String segment(Object payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '${segment(<String, String>{'alg': 'HS256'})}.${segment(<String, int>{'exp': expSeconds})}.sig';
}
