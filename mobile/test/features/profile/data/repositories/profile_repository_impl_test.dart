import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:libu_care/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

const _validJson = <String, dynamic>{
  'birthYear': 1968,
  'preferredLanguage': 'en',
  'heightCm': 172.0,
  'chdStage': 'Coronary artery disease',
  'diseaseHistory': null,
  'comorbidities': <dynamic>['diabetes'],
  'managementPlan': null,
  'goals': null,
};

void main() {
  test('saving while online writes locally and PUTs', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio()
      ..stub('/api/v1/patients/me', FakeResponse.ok(_validJson));
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
      isOnline: () async => true,
    );
    final profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);

    await repo.saveProfile(profile);

    expect(fake.requests.single.method, 'PUT');
    expect((await repo.getProfile('u1')).birthYear, 1968);
    expect(await repo.isDirty('u1'), isFalse);
  });

  test(
    'saving while offline writes locally, marks dirty, and makes no request',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio();
      final repo = ProfileRepositoryImpl(
        remote: ProfileRemoteDataSource(fake.dio),
        local: ProfileLocalDataSource(
          db: db,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => false,
      );
      final profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);

      await repo.saveProfile(profile);

      expect(fake.requests, isEmpty);
      expect((await repo.getProfile('u1')).birthYear, 1968);
      expect(await repo.isDirty('u1'), isTrue);
    },
  );

  test('a failed PUT leaves the local row intact and still dirty, and does not throw', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio()
      ..stub('/api/v1/patients/me', FakeResponse.error(500, 'Server error'));
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
      isOnline: () async => true,
    );
    final profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);

    await repo.saveProfile(profile);

    expect((await repo.getProfile('u1')).birthYear, 1968);
    expect(await repo.isDirty('u1'), isTrue);
  });

  test('a 400 on save is swallowed the same way - the local write already succeeded', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio()
      ..stub(
        '/api/v1/patients/me',
        FakeResponse.error(400, 'birthYear: must be between 1900 and 2100'),
      );
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
      isOnline: () async => true,
    );
    final profile = PatientProfile.empty('u1').copyWith(birthYear: 1500);

    await repo.saveProfile(profile);

    expect(await repo.isDirty('u1'), isTrue);
  });

  test('a malformed 200 (missing data) is swallowed the same way as a DioException, and does not throw (I4, final review)', () async {
    final db = testDatabase();
    addTearDown(db.close);

    final fake = FakeDio()..stub('/api/v1/patients/me', FakeResponse.ok(null));
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
      isOnline: () async => true,
    );
    final profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);

    await repo.saveProfile(profile);

    expect((await repo.getProfile('u1')).birthYear, 1968);
    expect(await repo.isDirty('u1'), isTrue);
  });

  test(
    'retryPendingSave also swallows a malformed 200 rather than throwing',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub('/api/v1/patients/me', FakeResponse.ok(null));
      final local = ProfileLocalDataSource(
        db: db,
        preferencesDao: db.preferencesDao,
      );
      await local.saveProfile(
        PatientProfile.empty('u1').copyWith(birthYear: 1968),
      );
      await local.setDirty('u1', true);
      final repo = ProfileRepositoryImpl(
        remote: ProfileRemoteDataSource(fake.dio),
        local: local,
        isOnline: () async => true,
      );

      await repo.retryPendingSave('u1');

      expect(await repo.isDirty('u1'), isTrue);
    },
  );

  test('retryPendingSave clears the dirty flag on success', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio()
      ..stub('/api/v1/patients/me', FakeResponse.ok(_validJson));
    final local = ProfileLocalDataSource(
      db: db,
      preferencesDao: db.preferencesDao,
    );
    await local.saveProfile(
      PatientProfile.empty('u1').copyWith(birthYear: 1968),
    );
    await local.setDirty('u1', true);
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: local,
      isOnline: () async => true,
    );

    await repo.retryPendingSave('u1');

    expect(await repo.isDirty('u1'), isFalse);
  });

  test('retryPendingSave is a no-op when the row is not dirty', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio();
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: ProfileLocalDataSource(db: db, preferencesDao: db.preferencesDao),
      isOnline: () async => true,
    );

    await repo.retryPendingSave('u1');

    expect(fake.requests, isEmpty);
  });

  test('getProfile returns the local row without making a request', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio();
    final local = ProfileLocalDataSource(
      db: db,
      preferencesDao: db.preferencesDao,
    );
    await local.saveProfile(PatientProfile.empty('u1').copyWith(heightCm: 172));
    final repo = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSource(fake.dio),
      local: local,
      isOnline: () async => true,
    );

    final result = await repo.getProfile('u1');

    expect(result.heightCm, 172);
    expect(fake.requests, isEmpty);
  });
}
