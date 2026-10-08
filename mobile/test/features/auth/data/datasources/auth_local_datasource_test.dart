import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/auth_fakes.dart';

const _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

String _jwt({required DateTime exp}) {
  String segment(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = segment(<String, dynamic>{'alg': 'none'});
  final payload = segment(<String, dynamic>{
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.signature';
}

void main() {
  late AppDatabase db;
  late AuthLocalDataSource ds;
  late FakeTokenStore tokens;

  setUp(() {
    db = testDatabase();
    tokens = FakeTokenStore();
    ds = AuthLocalDataSource(
      tokenStore: tokens,
      cachedUserDao: db.cachedUserDao,
      preferencesDao: db.preferencesDao,
    );
  });

  tearDown(() => db.close());

  test('saveSession writes both the token and the cached user', () async {
    await ds.saveSession(
      token: _jwt(exp: DateTime.now().add(const Duration(days: 7))),
      user: _user,
    );

    expect(await tokens.read(), isNotNull);
    expect(await ds.cachedUser(), _user);
  });

  test(
    'saveSession keeps the refresh token next to the access token',
    () async {
      await ds.saveSession(
        token: _jwt(exp: DateTime.now().add(const Duration(hours: 1))),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
        user: _user,
      );

      expect(await tokens.readRefresh(), 'refresh-1');
    },
  );

  test(
    'an expired access token with a live refresh token is still signed in',
    () async {
      await ds.saveSession(
        token: _jwt(exp: DateTime.now().subtract(const Duration(minutes: 1))),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
        user: _user,
      );

      expect(await ds.isSignedIn(), isTrue);
    },
  );

  test(
    'an expired refresh token does not keep the patient signed in',
    () async {
      await ds.saveSession(
        token: _jwt(exp: DateTime.now().subtract(const Duration(minutes: 1))),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        user: _user,
      );

      expect(await ds.isSignedIn(), isFalse);
    },
  );

  test('cachedUser is null before any session is saved', () async {
    expect(await ds.cachedUser(), isNull);
  });

  test('isSignedIn is false with no token', () async {
    expect(await ds.isSignedIn(), isFalse);
  });

  test('isSignedIn is true with a valid, unexpired token', () async {
    await ds.saveSession(
      token: _jwt(exp: DateTime.now().add(const Duration(days: 7))),
      user: _user,
    );
    expect(await ds.isSignedIn(), isTrue);
  });

  test('isSignedIn is false with a locally expired token', () async {
    await ds.saveSession(
      token: _jwt(exp: DateTime.now().subtract(const Duration(days: 1))),
      user: _user,
    );
    expect(await ds.isSignedIn(), isFalse);
  });

  test(
    'clearSession removes the token, the cached user, and the onboarding flag',
    () async {
      await ds.saveSession(
        token: _jwt(exp: DateTime.now().add(const Duration(days: 7))),
        user: _user,
      );
      await ds.setNeedsOnboarding(true);

      await ds.clearSession();

      expect(await tokens.read(), isNull);
      expect(await ds.cachedUser(), isNull);
      expect(await ds.needsOnboarding(), isFalse);
    },
  );

  test('needsOnboarding defaults to false and persists what is set', () async {
    expect(await ds.needsOnboarding(), isFalse);
    await ds.setNeedsOnboarding(true);
    expect(await ds.needsOnboarding(), isTrue);
  });
}
