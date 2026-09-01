import 'package:freezed_annotation/freezed_annotation.dart';

part 'patient_profile_model.freezed.dart';
part 'patient_profile_model.g.dart';

@freezed
abstract class PatientProfileModel with _$PatientProfileModel {
  const factory PatientProfileModel({
    int? birthYear,
    String? preferredLanguage,
    double? heightCm,
    String? chdStage,
    String? diseaseHistory,
    @Default([]) List<String> comorbidities,
    String? managementPlan,
    HealthGoalsModel? goals,
  }) = _PatientProfileModel;

  factory PatientProfileModel.fromJson(Map<String, dynamic> json) =>
      _$PatientProfileModelFromJson(json);
}

@freezed
abstract class HealthGoalsModel with _$HealthGoalsModel {
  const factory HealthGoalsModel({
    int? bpSystolic,
    int? bpDiastolic,
    double? totalCholesterol,
    int? stepsPerDay,
    double? targetWeightKg,
    String? dietNote,
  }) = _HealthGoalsModel;

  factory HealthGoalsModel.fromJson(Map<String, dynamic> json) =>
      _$HealthGoalsModelFromJson(json);
}