import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('CachedUserDao', () {
    test('returns null before anything is cached', () async {
      expect(await db.cachedUserDao.current(), isNull);
    });

    test('round-trips the cached user', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b'),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('am'),
        role: Value('PATIENT'),
      ));

      final user = await db.cachedUserDao.current();
      expect(user!.name, 'Abebe Bekele');
      expect(user.phone, '+251911234567');
      expect(user.preferredLanguage, 'am');
    });

    test('save replaces rather than accumulates', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-1'), name: Value('First'), phone: Value('+251911111111'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-2'), name: Value('Second'), phone: Value('+251922222222'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));

      expect(await db.select(db.cachedUsers).get(), hasLength(1));
      expect((await db.cachedUserDao.current())!.name, 'Second');
    });

    test('clear empties the cache on logout', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-1'), name: Value('First'), phone: Value('+251911111111'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));
      await db.cachedUserDao.clear();
      expect(await db.cachedUserDao.current(), isNull);
    });
  });

  group('PreferencesDao', () {
    test('returns null for an unset key', () async {
      expect(await db.preferencesDao.get(PreferenceKeys.language), isNull);
    });

    test('round-trips and overwrites a preference', () async {
      await db.preferencesDao.set(PreferenceKeys.language, 'en');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'en');
      await db.preferencesDao.set(PreferenceKeys.language, 'am');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'am');
    });
  });
}
