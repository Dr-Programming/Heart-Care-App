import 'health_goals.dart';

class PatientProfile {
  final int? birthYear;
  final String? preferredLanguage;
  final double? heightCm;
  final String? chdStage;
  final String? diseaseHistory;
  final List<String> comorbidities;
  final String? managementPlan;
  final HealthGoals? goals;

  const PatientProfile({
    this.birthYear,
    this.preferredLanguage,
    this.heightCm,
    this.chdStage,
    this.diseaseHistory,
    this.comorbidities = const [],
    this.managementPlan,
    this.goals,
  });

  PatientProfile copyWith({
    int? birthYear,
    String? preferredLanguage,
    double? heightCm,
    String? chdStage,
    String? diseaseHistory,
    List<String>? comorbidities,
    String? managementPlan,
    HealthGoals? goals,
  }) {
    return PatientProfile(
      birthYear: birthYear ?? this.birthYear,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      heightCm: heightCm ?? this.heightCm,
      chdStage: chdStage ?? this.chdStage,
      diseaseHistory: diseaseHistory ?? this.diseaseHistory,
      comorbidities: comorbidities ?? this.comorbidities,
      managementPlan: managementPlan ?? this.managementPlan,
      goals: goals ?? this.goals,
    );
  }
}