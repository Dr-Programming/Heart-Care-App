import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart';
import '../models/patient_profile_model.dart';

class ProfileLocalDatasource {
  final AppDatabase db;

  ProfileLocalDatasource(this.db);

  /// Returns the cached profile for this user, or an empty model if none has
  /// been saved locally yet — mirrors the backend's "no 404" behavior.
  Future<PatientProfileModel> getProfile(String userId) async {
    final row = await (db.select(
      db.patientProfiles,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();

    if (row == null) {
      return const PatientProfileModel();
    }

    return _rowToModel(row);
  }

  /// Full upsert — always writes the complete profile, matching the
  /// backend's full-replace PUT semantics.
  Future<void> saveProfile(String userId, PatientProfileModel model) async {
    await db
        .into(db.patientProfiles)
        .insertOnConflictUpdate(
          PatientProfilesCompanion(
            userId: Value(userId),
            birthYear: Value(model.birthYear),
            preferredLanguage: Value(model.preferredLanguage),
            heightCm: Value(model.heightCm),
            chdStage: Value(model.chdStage),
            diseaseHistory: Value(model.diseaseHistory),
            comorbiditiesJson: Value(jsonEncode(model.comorbidities)),
            managementPlan: Value(model.managementPlan),
            goalsJson: Value(
              model.goals == null ? null : jsonEncode(model.goals!.toJson()),
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  PatientProfileModel _rowToModel(PatientProfile row) {
    return PatientProfileModel(
      birthYear: row.birthYear,
      preferredLanguage: row.preferredLanguage,
      heightCm: row.heightCm,
      chdStage: row.chdStage,
      diseaseHistory: row.diseaseHistory,
      comorbidities: List<String>.from(
        jsonDecode(row.comorbiditiesJson) as List,
      ),
      managementPlan: row.managementPlan,
      goals: row.goalsJson == null
          ? null
          : HealthGoalsModel.fromJson(
              jsonDecode(row.goalsJson!) as Map<String, dynamic>,
            ),
    );
  }
}