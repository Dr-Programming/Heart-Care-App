import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/security/jwt.dart';

/// Builds a token whose payload carries the given `exp` (seconds since epoch).
String _tokenWithExp(int? exp) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg(<String, dynamic>{'sub': 'user-1', 'exp': ?exp});
  return '$header.$payload.signature-not-verified-on-device';
}

void main() {
  final DateTime now = DateTime.utc(2026, 8, 17, 12);

  test('a token expiring in the future is not expired', () {
    final t = _tokenWithExp(
      now.add(const Duration(days: 6)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(isJwtExpired(t, now: now), isFalse);
  });

  test('a token that expired an hour ago is expired', () {
    final t = _tokenWithExp(
      now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(isJwtExpired(t, now: now), isTrue);
  });

  test('a token with no exp claim is treated as expired', () {
    expect(isJwtExpired(_tokenWithExp(null), now: now), isTrue);
  });

  test('garbage is treated as expired rather than throwing', () {
    expect(isJwtExpired('not-a-jwt', now: now), isTrue);
    expect(isJwtExpired('', now: now), isTrue);
    expect(isJwtExpired('a.b.c', now: now), isTrue);
  });
}
