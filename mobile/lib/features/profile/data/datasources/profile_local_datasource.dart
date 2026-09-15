import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../../core/db/app_database.dart' as drift;
import '../../../../core/db/daos/preferences_dao.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';

class ProfileLocalDataSource {
  const ProfileLocalDataSource({
    required this.db,
    required this.preferencesDao,
  });

  final drift.AppDatabase db;
  final PreferencesDao preferencesDao;

  String _dirtyKey(String userId) => 'profile_dirty_$userId';

  Future<PatientProfile> getProfile(String userId) async {
    final drift.PatientProfile? row = await (db.select(
      db.patientProfiles,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    return row == null ? PatientProfile.empty(userId) : _fromRow(row);
  }

  Future<void> saveProfile(PatientProfile profile) async {
    await db
        .into(db.patientProfiles)
        .insertOnConflictUpdate(
          drift.PatientProfilesCompanion.insert(
            userId: profile.userId,
            birthYear: Value(profile.birthYear),
            preferredLanguage: Value(profile.preferredLanguage),
            heightCm: Value(profile.heightCm),
            chdStage: Value(profile.chdStage),
            diseaseHistory: Value(profile.diseaseHistory),
            comorbiditiesJson: Value(jsonEncode(profile.comorbidities)),
            managementPlan: Value(profile.managementPlan),
            goalsJson: Value(
              profile.goals == null
                  ? null
                  : jsonEncode(_goalsToJson(profile.goals!)),
            ),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<bool> isDirty(String userId) async =>
      await preferencesDao.get(_dirtyKey(userId)) == 'true';

  Future<void> setDirty(String userId, bool value) =>
      preferencesDao.set(_dirtyKey(userId), value.toString());

  Future<void> deleteProfile(String userId) async {
    await (db.delete(
      db.patientProfiles,
    )..where((t) => t.userId.equals(userId))).go();
    await preferencesDao.remove(_dirtyKey(userId));
  }

  PatientProfile _fromRow(drift.PatientProfile row) {
    return PatientProfile(
      userId: row.userId,
      birthYear: row.birthYear,
      preferredLanguage: row.preferredLanguage,
      heightCm: row.heightCm,
      chdStage: row.chdStage,
      diseaseHistory: row.diseaseHistory,
      comorbidities: (jsonDecode(row.comorbiditiesJson) as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      managementPlan: row.managementPlan,
      goals: row.goalsJson == null
          ? null
          : _goalsFromJson(jsonDecode(row.goalsJson!) as Map<String, dynamic>),
      updatedAt: row.updatedAt,
    );
  }

  HealthGoals _goalsFromJson(Map<String, dynamic> json) {
    return HealthGoals(
      bpSystolic: json['bpSystolic'] as int?,
      bpDiastolic: json['bpDiastolic'] as int?,
      totalCholesterol: (json['totalCholesterol'] as num?)?.toDouble(),
      stepsPerDay: json['stepsPerDay'] as int?,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      dietNote: json['dietNote'] as String?,
    );
  }

  Map<String, dynamic> _goalsToJson(HealthGoals g) => <String, dynamic>{
    'bpSystolic': g.bpSystolic,
    'bpDiastolic': g.bpDiastolic,
    'totalCholesterol': g.totalCholesterol,
    'stepsPerDay': g.stepsPerDay,
    'targetWeightKg': g.targetWeightKg,
    'dietNote': g.dietNote,
  };
}
