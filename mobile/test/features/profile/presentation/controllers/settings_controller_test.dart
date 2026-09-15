import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide PatientProfile;
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';
import 'package:libu_care/features/profile/presentation/controllers/settings_controller.dart';
import 'package:libu_care/features/profile/profile_providers.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

void _mockSecureStorageChannel() {
  final Map<String, String> store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final Map<Object?, Object?> args =
              (call.arguments as Map<Object?, Object?>?) ??
              const <Object?, Object?>{};
          switch (call.method) {
            case 'write':
              store[args['key'] as String] = args['value'] as String;
              return null;
            case 'read':
              return store[args['key'] as String];
            case 'delete':
              store.remove(args['key'] as String);
              return null;
            case 'containsKey':
              return store.containsKey(args['key'] as String);
            case 'deleteAll':
              store.clear();
              return null;
            case 'readAll':
              return store;
            default:
              return null;
          }
        },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    _mockSecureStorageChannel();
    db = testDatabase();
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value('u1'),
        name: Value('Test Patient'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );
    container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('changing the language writes LanguageStore and updates the profile, never reads the server value back', () async {
    final controller = container.read(settingsControllerProvider.notifier);

    await controller.changeLanguage(AppLanguage.am);

    expect(await container.read(languageStoreProvider).read(), AppLanguage.am);
    final profile = await container
        .read(profileRepositoryProvider)
        .getProfile('u1');
    expect(profile.preferredLanguage, AppLanguage.am.code);
  });

  test(
    'signOut clears the token, the cached user, and the needs-onboarding flag',
    () async {
      await db.preferencesDao.set('auth_needs_onboarding', 'true');
      final tokenStore = container.read(tokenStoreProvider);
      await tokenStore.write('a-real-token');

      final controller = container.read(settingsControllerProvider.notifier);
      await controller.signOut();

      expect(await tokenStore.read(), isNull);
      expect(await db.cachedUserDao.current(), isNull);
      expect(await db.preferencesDao.get('auth_needs_onboarding'), isNull);
    },
  );

  test('signOut also deletes the local PatientProfiles row for the signed-out user (I9, final review)', () async {
    final repo = container.read(profileRepositoryProvider);

    await repo.saveProfile(
      PatientProfile.empty('u1').copyWith(
        birthYear: 1968,
        heightCm: 172,
        comorbidities: const <String>['diabetes', 'hypertension'],
      ),
    );
    expect((await repo.getProfile('u1')).birthYear, 1968);

    final controller = container.read(settingsControllerProvider.notifier);
    await controller.signOut();

    final PatientProfile after = await repo.getProfile('u1');
    expect(after.birthYear, isNull);
    expect(after.heightCm, isNull);
    expect(after.comorbidities, isEmpty);
    expect(await repo.isDirty('u1'), isFalse);
  });

  test('retrySync delegates to the profile repository', () async {
    final controller = container.read(settingsControllerProvider.notifier);

    await controller.retrySync('u1');

    expect(
      await container.read(profileRepositoryProvider).isDirty('u1'),
      isFalse,
    );
  });
}
