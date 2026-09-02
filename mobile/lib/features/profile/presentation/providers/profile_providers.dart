import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/profile_local_datasource.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/save_profile.dart';
import '../../domain/usecases/set_language.dart';

final Provider<ProfileLocalDatasource> profileLocalDatasourceProvider =
    Provider<ProfileLocalDatasource>(
  (Ref ref) => ProfileLocalDatasource(ref.watch(appDatabaseProvider)),
);

final Provider<ProfileRemoteDatasource> profileRemoteDatasourceProvider =
    Provider<ProfileRemoteDatasource>(
  (Ref ref) => ProfileRemoteDatasource(ref.watch(dioProvider)),
);

/// Depends on the currently cached user's id. Throws if read before a user is
/// cached — every screen that reaches this provider is already past the auth
/// gate, so a signed-in user is expected to exist.
final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
  final cachedUser = ref.watch(cachedUserProvider).value;
  if (cachedUser == null) {
    throw StateError('profileRepositoryProvider read with no cached user.');
  }

  // Passing the live connectivity stream here means a profile edit made
  // offline retries on its own the moment the device reconnects, rather
  // than waiting for the patient to open the edit form again (M2 spec §5).
  final ProfileRepositoryImpl repository = ProfileRepositoryImpl(
    local: ref.watch(profileLocalDatasourceProvider),
    remote: ref.watch(profileRemoteDatasourceProvider),
    userId: cachedUser.id,
    prefsDao: ref.watch(appDatabaseProvider).preferencesDao,
    connectivity: ref.watch(connectivityStreamProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final Provider<GetProfile> getProfileProvider = Provider<GetProfile>(
  (Ref ref) => GetProfile(ref.watch(profileRepositoryProvider)),
);

final Provider<SaveProfile> saveProfileProvider = Provider<SaveProfile>(
  (Ref ref) => SaveProfile(ref.watch(profileRepositoryProvider)),
);

final Provider<SetLanguage> setLanguageProvider = Provider<SetLanguage>(
  (Ref ref) => SetLanguage(ref.watch(profileRepositoryProvider)),
);

/// The current patient profile, fetched once and cached by Riverpod. Screens
/// that display or edit the profile should watch this rather than call
/// GetProfile directly.
final FutureProvider<PatientProfile> patientProfileProvider =
    FutureProvider<PatientProfile>(
  (Ref ref) => ref.watch(getProfileProvider)(),
);