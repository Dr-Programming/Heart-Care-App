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

  ProfileRepositoryImpl({
    required this.local,
    required this.remote,
    required this.userId,
  });

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
    // five SyncEntityTypes), so on failure we simply leave the local copy as
    // the most recent truth and let the next explicit save retry the PUT.
    try {
      final saved = await remote.saveProfile(model);
      await local.saveProfile(userId, saved);
      return _toEntity(saved);
    } catch (_) {
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
    } catch (_) {
      // Server sync can retry later; the local language choice already took
      // effect above.
    }
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