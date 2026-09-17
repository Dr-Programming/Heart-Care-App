import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/models/user_model.dart';

import '../../../helpers/fake_jwt.dart';
import '../../../helpers/fake_secure_storage.dart';
import '../../../helpers/test_database.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();
const TokenStore _tokenStore = TokenStore(_storage);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpFakeSecureStorage);

  const UserModel user = UserModel(
    id: 'u1',
    name: 'Abebe Girma',
    phone: '+251911234567',
    preferredLanguage: 'en',
    role: 'PATIENT',
  );

  AuthLocalDataSource makeDataSource(AppDatabase db) => AuthLocalDataSource(
    tokenStore: _tokenStore,
    cachedUserDao: db.cachedUserDao,
  );

  test('saveSession writes the token and caches the user together', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);

    await ds.saveSession(token: 'jwt-token', user: user);

    expect(await ds.readToken(), 'jwt-token');
    final UserModel? cached = await ds.cachedUser();
    expect(cached?.id, 'u1');
    expect(cached?.name, 'Abebe Girma');
  });

  test('clearSession removes both the token and the cached user', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);
    await ds.saveSession(token: 'jwt-token', user: user);

    await ds.clearSession();

    expect(await ds.readToken(), isNull);
    expect(await ds.cachedUser(), isNull);
  });

  test('hasValidSession is false when no token is stored', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);

    expect(await ds.hasValidSession(), isFalse);
  });

  test('hasValidSession is false for an unreadable token', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);
    await _tokenStore.write('not-a-jwt');

    expect(await ds.hasValidSession(), isFalse);
  });

  test('hasValidSession is true for an unexpired token', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);
    await _tokenStore.write(
      fakeJwt(expiresAt: DateTime.now().add(const Duration(days: 7))),
    );

    expect(await ds.hasValidSession(), isTrue);
  });

  test(
    'cacheUser refreshes the cached user without touching the token',
    () async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final AuthLocalDataSource ds = makeDataSource(db);
      await ds.saveSession(token: 'jwt-token', user: user);
      const UserModel renamed = UserModel(
        id: 'u1',
        name: 'Abebe G.',
        phone: '+251911234567',
        preferredLanguage: 'am',
        role: 'PATIENT',
      );

      await ds.cacheUser(renamed);

      expect(await ds.readToken(), 'jwt-token');
      final UserModel? cached = await ds.cachedUser();
      expect(cached?.name, 'Abebe G.');
      expect(cached?.preferredLanguage, 'am');
    },
  );

  test('hasValidSession is false for an expired token', () async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final AuthLocalDataSource ds = makeDataSource(db);
    await _tokenStore.write(
      fakeJwt(expiresAt: DateTime.now().subtract(const Duration(days: 1))),
    );

    expect(await ds.hasValidSession(), isFalse);
  });
}
