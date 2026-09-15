import 'health_goals.dart';

class PatientProfile {
  const PatientProfile({
    required this.userId,
    required this.birthYear,
    required this.preferredLanguage,
    required this.heightCm,
    required this.chdStage,
    required this.diseaseHistory,
    required this.comorbidities,
    required this.managementPlan,
    required this.goals,
    required this.updatedAt,
  });

  factory PatientProfile.empty(String userId) => PatientProfile(
    userId: userId,
    birthYear: null,
    preferredLanguage: null,
    heightCm: null,
    chdStage: null,
    diseaseHistory: null,
    comorbidities: const <String>[],
    managementPlan: null,
    goals: null,
    updatedAt: null,
  );

  final String userId;
  final int? birthYear;
  final String? preferredLanguage;
  final double? heightCm;
  final String? chdStage;
  final String? diseaseHistory;
  final List<String> comorbidities;
  final String? managementPlan;
  final HealthGoals? goals;
  final DateTime? updatedAt;

  PatientProfile copyWith({
    int? birthYear,
    String? preferredLanguage,
    double? heightCm,
    String? chdStage,
    String? diseaseHistory,
    List<String>? comorbidities,
    String? managementPlan,
    HealthGoals? goals,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      userId: userId,
      birthYear: birthYear ?? this.birthYear,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      heightCm: heightCm ?? this.heightCm,
      chdStage: chdStage ?? this.chdStage,
      diseaseHistory: diseaseHistory ?? this.diseaseHistory,
      comorbidities: comorbidities ?? this.comorbidities,
      managementPlan: managementPlan ?? this.managementPlan,
      goals: goals ?? this.goals,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          birthYear == other.birthYear &&
          preferredLanguage == other.preferredLanguage &&
          heightCm == other.heightCm &&
          chdStage == other.chdStage &&
          diseaseHistory == other.diseaseHistory &&
          _listEquals(comorbidities, other.comorbidities) &&
          managementPlan == other.managementPlan &&
          goals == other.goals &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    userId,
    birthYear,
    preferredLanguage,
    heightCm,
    chdStage,
    diseaseHistory,
    Object.hashAll(comorbidities),
    managementPlan,
    goals,
    updatedAt,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
