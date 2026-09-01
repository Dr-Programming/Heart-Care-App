import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';

void main() {
  late AppDatabase db;
  late ProfileLocalDatasource datasource;

  const userId = 'user-1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    datasource = ProfileLocalDatasource(db);
  });

  tearDown(() => db.close());

  group('getProfile', () {
    test('returns an empty model before anything is saved', () async {
      final result = await datasource.getProfile(userId);

      expect(result.birthYear, isNull);
      expect(result.preferredLanguage, isNull);
      expect(result.heightCm, isNull);
      expect(result.comorbidities, isEmpty);
      expect(result.goals, isNull);
    });
  });

  group('saveProfile / getProfile round trip', () {
    test('round-trips simple fields', () async {
      const model = PatientProfileModel(
        birthYear: 1965,
        preferredLanguage: 'am',
        heightCm: 172.0,
        chdStage: 'Coronary artery disease',
        diseaseHistory: 'Diagnosed 2019',
        managementPlan: 'Beta-blocker, daily walk',
      );

      await datasource.saveProfile(userId, model);
      final result = await datasource.getProfile(userId);

      expect(result.birthYear, 1965);
      expect(result.preferredLanguage, 'am');
      expect(result.heightCm, 172.0);
      expect(result.chdStage, 'Coronary artery disease');
      expect(result.diseaseHistory, 'Diagnosed 2019');
      expect(result.managementPlan, 'Beta-blocker, daily walk');
    });

    test('round-trips the comorbidities list', () async {
      const model = PatientProfileModel(
        comorbidities: ['Diabetes', 'Hypertension'],
      );

      await datasource.saveProfile(userId, model);
      final result = await datasource.getProfile(userId);

      expect(result.comorbidities, ['Diabetes', 'Hypertension']);
    });

    test('round-trips an empty comorbidities list', () async {
      const model = PatientProfileModel();

      await datasource.saveProfile(userId, model);
      final result = await datasource.getProfile(userId);

      expect(result.comorbidities, isEmpty);
    });

    test('round-trips the goals object', () async {
      const model = PatientProfileModel(
        goals: HealthGoalsModel(
          bpSystolic: 120,
          bpDiastolic: 80,
          totalCholesterol: 180.0,
          stepsPerDay: 8000,
          targetWeightKg: 70.0,
          dietNote: 'Low salt',
        ),
      );

      await datasource.saveProfile(userId, model);
      final result = await datasource.getProfile(userId);

      expect(result.goals, isNotNull);
      expect(result.goals!.bpSystolic, 120);
      expect(result.goals!.bpDiastolic, 80);
      expect(result.goals!.totalCholesterol, 180.0);
      expect(result.goals!.stepsPerDay, 8000);
      expect(result.goals!.targetWeightKg, 70.0);
      expect(result.goals!.dietNote, 'Low salt');
    });

    test('returns null goals when none were ever saved', () async {
      const model = PatientProfileModel(birthYear: 1970);

      await datasource.saveProfile(userId, model);
      final result = await datasource.getProfile(userId);

      expect(result.goals, isNull);
    });

    test('saving again overwrites the full profile (full-replace semantics)', () async {
      const first = PatientProfileModel(
        birthYear: 1965,
        chdStage: 'Coronary artery disease',
        comorbidities: ['Diabetes'],
      );
      const second = PatientProfileModel(birthYear: 1965);

      await datasource.saveProfile(userId, first);
      await datasource.saveProfile(userId, second);
      final result = await datasource.getProfile(userId);

      // chdStage and comorbidities from the first save must be gone, not merged.
      expect(result.chdStage, isNull);
      expect(result.comorbidities, isEmpty);
      expect(result.birthYear, 1965);
    });

    test('profiles for different users do not collide', () async {
      const modelA = PatientProfileModel(birthYear: 1965);
      const modelB = PatientProfileModel(birthYear: 1980);

      await datasource.saveProfile('user-a', modelA);
      await datasource.saveProfile('user-b', modelB);

      expect((await datasource.getProfile('user-a')).birthYear, 1965);
      expect((await datasource.getProfile('user-b')).birthYear, 1980);
    });
  });
}