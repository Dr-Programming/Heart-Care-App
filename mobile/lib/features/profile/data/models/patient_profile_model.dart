import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';

part 'patient_profile_model.freezed.dart';

@freezed
abstract class HealthGoalsModel with _$HealthGoalsModel {
  const HealthGoalsModel._();

  const factory HealthGoalsModel({
    int? bpSystolic,
    int? bpDiastolic,
    double? totalCholesterol,
    int? stepsPerDay,
    double? targetWeightKg,
    String? dietNote,
  }) = _HealthGoalsModel;

  factory HealthGoalsModel.fromJson(Map<String, dynamic> json) {
    return HealthGoalsModel(
      bpSystolic: json['bpSystolic'] as int?,
      bpDiastolic: json['bpDiastolic'] as int?,
      totalCholesterol: (json['totalCholesterol'] as num?)?.toDouble(),
      stepsPerDay: json['stepsPerDay'] as int?,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      dietNote: json['dietNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bpSystolic': bpSystolic,
    'bpDiastolic': bpDiastolic,
    'totalCholesterol': totalCholesterol,
    'stepsPerDay': stepsPerDay,
    'targetWeightKg': targetWeightKg,
    'dietNote': dietNote,
  };

  HealthGoals toDomain() => HealthGoals(
    bpSystolic: bpSystolic,
    bpDiastolic: bpDiastolic,
    totalCholesterol: totalCholesterol,
    stepsPerDay: stepsPerDay,
    targetWeightKg: targetWeightKg,
    dietNote: dietNote,
  );

  factory HealthGoalsModel.fromDomain(HealthGoals goals) => HealthGoalsModel(
    bpSystolic: goals.bpSystolic,
    bpDiastolic: goals.bpDiastolic,
    totalCholesterol: goals.totalCholesterol,
    stepsPerDay: goals.stepsPerDay,
    targetWeightKg: goals.targetWeightKg,
    dietNote: goals.dietNote,
  );
}

@freezed
abstract class PatientProfileModel with _$PatientProfileModel {
  const PatientProfileModel._();

  const factory PatientProfileModel({
    int? birthYear,
    String? preferredLanguage,
    double? heightCm,
    String? chdStage,
    String? diseaseHistory,
    required List<String> comorbidities,
    String? managementPlan,
    HealthGoalsModel? goals,
  }) = _PatientProfileModel;

  factory PatientProfileModel.fromJson(Map<String, dynamic> json) {
    return PatientProfileModel(
      birthYear: json['birthYear'] as int?,
      preferredLanguage: json['preferredLanguage'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      chdStage: json['chdStage'] as String?,
      diseaseHistory: json['diseaseHistory'] as String?,
      comorbidities:
          (json['comorbidities'] as List<dynamic>?)
              ?.map((Object? e) => e as String)
              .toList() ??
          <String>[],
      managementPlan: json['managementPlan'] as String?,
      goals: json['goals'] == null
          ? null
          : HealthGoalsModel.fromJson(json['goals'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'birthYear': birthYear,
    'preferredLanguage': preferredLanguage,
    'heightCm': heightCm,
    'chdStage': chdStage,
    'diseaseHistory': diseaseHistory,
    'comorbidities': comorbidities,
    'managementPlan': managementPlan,
    'goals': goals?.toJson(),
  };

  PatientProfile toDomain(String userId) => PatientProfile(
    userId: userId,
    birthYear: birthYear,
    preferredLanguage: preferredLanguage,
    heightCm: heightCm,
    chdStage: chdStage,
    diseaseHistory: diseaseHistory,
    comorbidities: comorbidities,
    managementPlan: managementPlan,
    goals: goals?.toDomain(),
    updatedAt: null,
  );

  factory PatientProfileModel.fromDomain(PatientProfile profile) =>
      PatientProfileModel(
        birthYear: profile.birthYear,
        preferredLanguage: profile.preferredLanguage,
        heightCm: profile.heightCm,
        chdStage: profile.chdStage,
        diseaseHistory: profile.diseaseHistory,
        comorbidities: profile.comorbidities,
        managementPlan: profile.managementPlan,
        goals: profile.goals == null
            ? null
            : HealthGoalsModel.fromDomain(profile.goals!),
      );
}
