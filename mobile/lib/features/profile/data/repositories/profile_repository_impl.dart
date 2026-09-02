import 'dart:async';

import '../../../../core/db/daos/preferences_dao.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/patient_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileLocalDatasource local;
  final ProfileRemoteDatasource remote;
  final String userId;

  /// Optional so existing callers (and every current test) that only care
  /// about the local-first read/write path can keep constructing this class
  /// without them. Only the "retry on reconnect" behaviour below needs them.
  final PreferencesDao? prefsDao;

  StreamSubscription<bool>? _connectivitySub;

  ProfileRepositoryImpl({
    required this.local,
    required this.remote,
    required this.userId,
    this.prefsDao,
    Stream<bool>? connectivity,
  }) {
    // A PUT that failed while offline is marked dirty below and left for the
    // patient's next explicit edit to retry — except that may be days away.
    // Listening here means it also retries the moment the device comes back
    // online, with no user action required (M2 spec §5).
    if (connectivity != null) {
      // connectivity_plus reports a stream error rather than a value when the
      // platform channel is unavailable (as under `flutter test`) — swallow
      // it the same way SyncService does, rather than let it become an
      // unhandled async error with no listener for it.
      _connectivitySub = connectivity.handleError((Object _) {}).listen((
        bool online,
      ) {
        if (online) unawaited(retryPendingSync());
      });
    }
  }

  /// A per-user key: two accounts on the same device must not see each
  /// other's "still needs to sync" flag.
  String get _dirtyKey => 'profile_dirty_$userId';

  @override
  Future<PatientProfile> getProfile() async {
    // Local is always the source of truth for reads. If nothing has ever
    // synced, this returns an empty profile — never an error.
    final model = await local.getProfile(userId);
    return _toEntity(model);
  }

  @override
  Future<PatientProfile> saveProfile(PatientProfile profile) async {
    final model = _toModel(profile);

    // Write locally first — the patient's edit is never lost even if the
    // network call below fails.
    await local.saveProfile(userId, model);

    // Then attempt to push to the server opportunistically. Profile writes
    // are NOT part of the batch /sync endpoint (profile is not one of the
    // five SyncEntityTypes), so this repository owns its own tiny retry
    // loop instead: a failed PUT marks the row dirty and [retryPendingSync]
    // picks it up again on the next reconnect or the next explicit save.
    try {
      final saved = await remote.saveProfile(model);
      await local.saveProfile(userId, saved);
      await prefsDao?.remove(_dirtyKey);
      return _toEntity(saved);
    } catch (_) {
      await prefsDao?.set(_dirtyKey, 'true');
      return profile;
    }
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    // Device-local setting takes effect immediately regardless of the
    // network. We also try to keep the server's copy of preferredLanguage
    // in step, but never block or fail the local switch on that call.
    final current = await local.getProfile(userId);
    final updated = current.copyWith(preferredLanguage: languageCode);
    await local.saveProfile(userId, updated);

    try {
      final saved = await remote.saveProfile(updated);
      await local.saveProfile(userId, saved);
      await prefsDao?.remove(_dirtyKey);
    } catch (_) {
      // Server sync can retry later; the local language choice already took
      // effect above.
      await prefsDao?.set(_dirtyKey, 'true');
    }
  }

  /// Pushes the local profile again if an earlier save or language change
  /// failed to reach the server. A no-op when nothing is dirty, so it is
  /// safe to call on every reconnect rather than only when the caller knows
  /// something is pending.
  Future<void> retryPendingSync() async {
    final PreferencesDao? prefs = prefsDao;
    if (prefs == null) return;
    if (await prefs.get(_dirtyKey) != 'true') return;

    final model = await local.getProfile(userId);
    try {
      final saved = await remote.saveProfile(model);
      await local.saveProfile(userId, saved);
      await prefs.remove(_dirtyKey);
    } catch (_) {
      // Still failing — leave the flag set for the next attempt.
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  PatientProfile _toEntity(PatientProfileModel model) {
    return PatientProfile(
      birthYear: model.birthYear,
      preferredLanguage: model.preferredLanguage,
      heightCm: model.heightCm,
      chdStage: model.chdStage,
      diseaseHistory: model.diseaseHistory,
      comorbidities: model.comorbidities,
      managementPlan: model.managementPlan,
      goals: model.goals == null
          ? null
          : HealthGoals(
              bpSystolic: model.goals!.bpSystolic,
              bpDiastolic: model.goals!.bpDiastolic,
              totalCholesterol: model.goals!.totalCholesterol,
              stepsPerDay: model.goals!.stepsPerDay,
              targetWeightKg: model.goals!.targetWeightKg,
              dietNote: model.goals!.dietNote,
            ),
    );
  }

  PatientProfileModel _toModel(PatientProfile entity) {
    return PatientProfileModel(
      birthYear: entity.birthYear,
      preferredLanguage: entity.preferredLanguage,
      heightCm: entity.heightCm,
      chdStage: entity.chdStage,
      diseaseHistory: entity.diseaseHistory,
      comorbidities: entity.comorbidities,
      managementPlan: entity.managementPlan,
      goals: entity.goals == null
          ? null
          : HealthGoalsModel(
              bpSystolic: entity.goals!.bpSystolic,
              bpDiastolic: entity.goals!.bpDiastolic,
              totalCholesterol: entity.goals!.totalCholesterol,
              stepsPerDay: entity.goals!.stepsPerDay,
              targetWeightKg: entity.goals!.targetWeightKg,
              dietNote: entity.goals!.dietNote,
            ),
    );
  }
}
