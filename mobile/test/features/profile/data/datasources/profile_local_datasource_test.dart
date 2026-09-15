import 'package:flutter_test/flutter_test.dart';

import 'package:libu_care/core/db/app_database.dart' hide PatientProfile;
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileLocalDataSource ds;

  setUp(() {
    db = testDatabase();
    ds = ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao);
  });

  tearDown(() => db.close());

  test(
    'getProfile returns the empty shape when nothing has been saved',
    () async {
      final profile = await ds.getProfile('u1');
      expect(profile, PatientProfile.empty('u1'));
    },
  );

  test('saveProfile then getProfile round-trips a full profile, including comorbidities and goals', () async {
    final profile = PatientProfile.empty('u1').copyWith(
      birthYear: 1968,
      heightCm: 172,
      chdStage: 'Coronary artery disease',
      comorbidities: <String>['diabetes', 'hypertension'],
      goals: const HealthGoals(stepsPerDay: 6000, dietNote: 'Less salt'),
    );

    await ds.saveProfile(profile);
    final result = await ds.getProfile('u1');

    expect(result.birthYear, 1968);
    expect(result.comorbidities, <String>['diabetes', 'hypertension']);
    expect(result.goals?.stepsPerDay, 6000);
    expect(result.goals?.dietNote, 'Less salt');
  });

  test('an empty comorbidity list survives a round-trip', () async {
    final profile = PatientProfile.empty('u1')
        .copyWith(birthYear: 1968, comorbidities: <String>[]);
    await ds.saveProfile(profile);
    final result = await ds.getProfile('u1');
    expect(result.comorbidities, isEmpty);
  });

  test('null goals survive a round-trip', () async {
    final profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);
    await ds.saveProfile(profile);
    final result = await ds.getProfile('u1');
    expect(result.goals, isNull);
  });

  test('saving twice replaces rather than accumulating', () async {
    await ds.saveProfile(PatientProfile.empty('u1').copyWith(heightCm: 170));
    await ds.saveProfile(PatientProfile.empty('u1').copyWith(heightCm: 175));
    final result = await ds.getProfile('u1');
    expect(result.heightCm, 175);
  });

  test('isDirty defaults to false and reflects what setDirty writes', () async {
    expect(await ds.isDirty('u1'), isFalse);
    await ds.setDirty('u1', true);
    expect(await ds.isDirty('u1'), isTrue);
    await ds.setDirty('u1', false);
    expect(await ds.isDirty('u1'), isFalse);
  });
}
