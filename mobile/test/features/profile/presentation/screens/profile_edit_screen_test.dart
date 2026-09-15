import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide PatientProfile;
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';
import 'package:libu_care/features/profile/presentation/screens/profile_edit_screen.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  Finder fieldByKey(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  Future<void> seedCachedUser(AppDatabase db) => db.cachedUserDao.save(
    const CachedUsersCompanion(
      id: Value('u1'),
      name: Value('Test Patient'),
      phone: Value('+251911234567'),
      preferredLanguage: Value('en'),
      role: Value('PATIENT'),
    ),
  );

  testWidgets('the form prefills every field from the current profile', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await seedCachedUser(db);
    await ProfileLocalDataSource(
      db: db,
      preferencesDao: db.preferencesDao,
    ).saveProfile(
      PatientProfile.empty('u1').copyWith(birthYear: 1968, heightCm: 172),
    );

    await pumpApp(
      tester,
      const ProfileEditScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('1968'), findsOneWidget);
    expect(find.text('172.0'), findsWidgets);
  });

  testWidgets('editing one field and saving does not clear any other field', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await seedCachedUser(db);
    final local = ProfileLocalDataSource(
      db: db,
      preferencesDao: db.preferencesDao,
    );
    await local.saveProfile(
      PatientProfile.empty('u1').copyWith(
        birthYear: 1968,
        preferredLanguage: 'am',
        heightCm: 172,
        diseaseHistory: 'Heart attack in 2020',
        comorbidities: <String>['diabetes', 'a custom note'],
        managementPlan: 'Low-sodium diet, daily walk',
        goals: const HealthGoals(
          bpSystolic: 120,
          bpDiastolic: 80,
          totalCholesterol: 190.5,
          stepsPerDay: 8000,
          targetWeightKg: 70.5,
          dietNote: 'Less salt',
        ),
      ),
    );

    await pumpApp(
      tester,
      const ProfileEditScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(fieldByKey('profile_edit_height_field'), '175');
    await tester.pump();
    await tester.tap(find.text('common.save'.tr()));
    await tester.pumpAndSettle();

    final saved = await local.getProfile('u1');
    expect(saved.heightCm, 175);
    expect(saved.birthYear, 1968);
    expect(saved.preferredLanguage, 'am');
    expect(saved.diseaseHistory, 'Heart attack in 2020');
    expect(saved.comorbidities, <String>['diabetes', 'a custom note']);
    expect(saved.managementPlan, 'Low-sodium diet, daily walk');
    expect(
      saved.goals,
      const HealthGoals(
        bpSystolic: 120,
        bpDiastolic: 80,
        totalCholesterol: 190.5,
        stepsPerDay: 8000,
        targetWeightKg: 70.5,
        dietNote: 'Less salt',
      ),
    );
    expect(saved.chdStage, 'Coronary artery disease');
  });

  testWidgets(
    'a negative goal value blocks save, shows the error, and the repository is never called (I6, final review)',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      await seedCachedUser(db);
      final local = ProfileLocalDataSource(
        db: db,
        preferencesDao: db.preferencesDao,
      );
      await local.saveProfile(
        PatientProfile.empty('u1').copyWith(
          birthYear: 1968,
          goals: const HealthGoals(stepsPerDay: 8000),
        ),
      );

      await pumpApp(
        tester,
        const ProfileEditScreen(),
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(FakeDio().dio),
          isOnlineProvider.overrideWithValue(() async => false),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(fieldByKey('profile_edit_steps_field'), '-5000');
      await tester.pump();
      await tester.tap(find.text('common.save'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('profile.errors.goalNegative'.tr()), findsOneWidget);

      final saved = await local.getProfile('u1');
      expect(saved.goals?.stepsPerDay, 8000);
    },
  );
}
