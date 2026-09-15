import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/presentation/controllers/onboarding_controller.dart';
import 'package:libu_care/features/profile/profile_providers.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
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

  test('answers survive a step change', () {
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.setBirthYear(1968);
    controller.next();
    controller.next();
    controller.back();
    controller.back();
    expect(container.read(onboardingControllerProvider).birthYear, 1968);
  });

  test('skipping step 2 still produces a valid profile on finish', () async {
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.setBirthYear(1968);
    controller.next();
    controller.next();

    await controller.finish();

    final profile = await container
        .read(profileRepositoryProvider)
        .getProfile('u1');
    expect(profile.birthYear, 1968);
    expect(profile.chdStage, 'Coronary artery disease');
  });

  test('finishing clears needsOnboarding', () async {
    final controller = container.read(onboardingControllerProvider.notifier);
    await controller.finish();

    final String? flag = await db.preferencesDao.get('auth_needs_onboarding');
    expect(flag, 'false');
  });

  test('skipping also clears needsOnboarding', () async {
    final controller = container.read(onboardingControllerProvider.notifier);
    await controller.skip();

    final String? flag = await db.preferencesDao.get('auth_needs_onboarding');
    expect(flag, 'false');
  });

  test('the profile is written exactly once across the whole wizard', () async {
    final fake = FakeDio()
      ..stub(
        '/api/v1/patients/me',
        FakeResponse.ok(const <String, dynamic>{
          'birthYear': 1968,
          'preferredLanguage': null,
          'heightCm': null,
          'chdStage': 'Coronary artery disease',
          'diseaseHistory': null,
          'comorbidities': <dynamic>[],
          'managementPlan': null,
          'goals': null,
        }),
      );
    final onlineContainer = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(fake.dio),
        isOnlineProvider.overrideWithValue(() async => true),
      ],
    );
    addTearDown(onlineContainer.dispose);
    final controller = onlineContainer.read(
      onboardingControllerProvider.notifier,
    );

    controller.setBirthYear(1968);
    controller.next();
    controller.next();
    controller.next();
    await controller.finish();

    expect(fake.requests.length, 1);
  });

  test(
    'finish persists reminder/notification choices to Preferences',
    () async {
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.setNotificationsOn(false);
      controller.setMedicationReminder(false);
      controller.setVitalsReminder(true);
      controller.setSymptomReminder(true);
      controller.setSymptomReminderTime('20:15');

      await controller.finish();

      expect(
        await db.preferencesDao.get(PreferenceKeys.notificationsEnabled),
        'false',
      );
      expect(
        await db.preferencesDao.get(PreferenceKeys.symptomPromptTime),
        '20:15',
      );
      expect(
        await db.preferencesDao.get('profile_medication_reminder_enabled'),
        'false',
      );
      expect(
        await db.preferencesDao.get('profile_vitals_reminder_enabled'),
        'true',
      );
      expect(
        await db.preferencesDao.get('profile_symptom_reminder_enabled'),
        'true',
      );
    },
  );

  test('the symptom prompt time defaults to 19:30 (7:30 PM) when never set, and skip persists too', () async {
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.setVitalsReminder(false);

    await controller.skip();

    expect(
      await db.preferencesDao.get(PreferenceKeys.symptomPromptTime),
      '19:30',
    );
    expect(
      await db.preferencesDao.get('profile_vitals_reminder_enabled'),
      'false',
    );

    expect(
      await db.preferencesDao.get(PreferenceKeys.notificationsEnabled),
      'true',
    );
    expect(
      await db.preferencesDao.get('profile_medication_reminder_enabled'),
      'true',
    );
    expect(
      await db.preferencesDao.get('profile_symptom_reminder_enabled'),
      'true',
    );
  });
}
