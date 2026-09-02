import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/daos/preferences_dao.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:libu_care/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockLocal extends Mock implements ProfileLocalDatasource {}

class MockRemote extends Mock implements ProfileRemoteDatasource {}

class MockPrefs extends Mock implements PreferencesDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientProfileModel());
  });

  late MockLocal local;
  late MockRemote remote;
  late ProfileRepositoryImpl repository;

  const userId = 'user-1';

  setUp(() {
    local = MockLocal();
    remote = MockRemote();
    repository = ProfileRepositoryImpl(
      local: local,
      remote: remote,
      userId: userId,
    );
  });

  group('getProfile', () {
    test('reads from local, never touches remote', () async {
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );

      final result = await repository.getProfile();

      expect(result.birthYear, 1965);
      verifyNever(() => remote.getProfile());
    });
  });

  group('saveProfile', () {
    test('writes locally before attempting the network', () async {
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );

      const profile = PatientProfile(birthYear: 1965);
      await repository.saveProfile(profile);

      verify(() => local.saveProfile(userId, any())).called(2);
    });

    test('returns the server-confirmed profile on a successful sync',
        () async {
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(
          birthYear: 1965,
          chdStage: 'server-confirmed',
        ),
      );

      final result = await repository.saveProfile(
        const PatientProfile(birthYear: 1965),
      );

      expect(result.chdStage, 'server-confirmed');
    });

    test(
      'returns the locally-saved profile without throwing when the network call fails',
      () async {
        when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
        when(() => remote.saveProfile(any())).thenThrow(Exception('offline'));

        const profile = PatientProfile(birthYear: 1965, chdStage: 'local-only');

        final result = await repository.saveProfile(profile);

        expect(result.birthYear, 1965);
        expect(result.chdStage, 'local-only');
      },
    );

    test('local write still happens even if remote later fails', () async {
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenThrow(Exception('offline'));

      await repository.saveProfile(const PatientProfile(birthYear: 1965));

      verify(() => local.saveProfile(userId, any())).called(1);
    });
  });

  group('setLanguage', () {
    test('updates the local profile immediately', () async {
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(
          birthYear: 1965,
          preferredLanguage: 'am',
        ),
      );

      await repository.setLanguage('am');

      final captured = verify(
        () => local.saveProfile(userId, captureAny()),
      ).captured;
      final firstSave = captured.first as PatientProfileModel;
      expect(firstSave.preferredLanguage, 'am');
    });

    test('does not throw when the network sync fails', () async {
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenThrow(Exception('offline'));

      await expectLater(repository.setLanguage('am'), completes);
    });
  });

  group('retry on reconnect', () {
    late MockPrefs prefs;

    setUp(() {
      prefs = MockPrefs();
      when(() => prefs.set(any(), any())).thenAnswer((_) async {});
      when(() => prefs.remove(any())).thenAnswer((_) async {});
    });

    test('a failed save marks the profile dirty', () async {
      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenThrow(Exception('offline'));

      await repository.saveProfile(const PatientProfile(birthYear: 1965));

      verify(() => prefs.set('profile_dirty_$userId', 'true')).called(1);
    });

    test('a successful save clears the dirty flag', () async {
      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );

      await repository.saveProfile(const PatientProfile(birthYear: 1965));

      verify(() => prefs.remove('profile_dirty_$userId')).called(1);
    });

    test('retryPendingSync does nothing when nothing is dirty', () async {
      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
      );
      when(() => prefs.get('profile_dirty_$userId')).thenAnswer((_) async => null);

      await repository.retryPendingSync();

      verifyNever(() => remote.saveProfile(any()));
    });

    test('retryPendingSync pushes the local copy when dirty, and clears the flag',
        () async {
      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
      );
      when(() => prefs.get('profile_dirty_$userId'))
          .thenAnswer((_) async => 'true');
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );

      await repository.retryPendingSync();

      verify(() => remote.saveProfile(any())).called(1);
      verify(() => prefs.remove('profile_dirty_$userId')).called(1);
    });

    test('retryPendingSync leaves the flag set if still offline', () async {
      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
      );
      when(() => prefs.get('profile_dirty_$userId'))
          .thenAnswer((_) async => 'true');
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );
      when(() => remote.saveProfile(any())).thenThrow(Exception('offline'));

      await repository.retryPendingSync();

      verifyNever(() => prefs.remove(any()));
    });

    test('a reconnect event triggers a retry automatically', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
        connectivity: controller.stream,
      );
      when(() => prefs.get('profile_dirty_$userId'))
          .thenAnswer((_) async => 'true');
      when(() => local.getProfile(userId)).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );
      when(() => local.saveProfile(userId, any())).thenAnswer((_) async {});
      when(() => remote.saveProfile(any())).thenAnswer(
        (_) async => const PatientProfileModel(birthYear: 1965),
      );

      controller.add(true);
      // The listener fires the retry asynchronously; give it a turn.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => remote.saveProfile(any())).called(1);
    });

    test('does not retry on a "gone offline" event', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      repository = ProfileRepositoryImpl(
        local: local,
        remote: remote,
        userId: userId,
        prefsDao: prefs,
        connectivity: controller.stream,
      );

      controller.add(false);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => prefs.get(any()));
    });
  });
}