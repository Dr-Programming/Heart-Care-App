import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';

void main() {
  test('PatientProfile.empty has every field null except userId', () {
    final profile = PatientProfile.empty('u1');
    expect(profile.userId, 'u1');
    expect(profile.birthYear, isNull);
    expect(profile.heightCm, isNull);
    expect(profile.chdStage, isNull);
    expect(profile.comorbidities, isEmpty);
    expect(profile.goals, isNull);
  });

  test('copyWith replaces only the given fields', () {
    final base = PatientProfile.empty('u1');
    final updated = base.copyWith(birthYear: 1968, heightCm: 172);
    expect(updated.birthYear, 1968);
    expect(updated.heightCm, 172);
    expect(updated.userId, 'u1');
    expect(updated.chdStage, isNull);
  });

  test('two PatientProfiles with the same fields are equal', () {
    const a = PatientProfile(
      userId: 'u1',
      birthYear: 1968,
      preferredLanguage: 'en',
      heightCm: 172,
      chdStage: 'Coronary artery disease',
      diseaseHistory: null,
      comorbidities: <String>['diabetes'],
      managementPlan: null,
      goals: null,
      updatedAt: null,
    );
    const b = PatientProfile(
      userId: 'u1',
      birthYear: 1968,
      preferredLanguage: 'en',
      heightCm: 172,
      chdStage: 'Coronary artery disease',
      diseaseHistory: null,
      comorbidities: <String>['diabetes'],
      managementPlan: null,
      goals: null,
      updatedAt: null,
    );
    expect(a, equals(b));
  });

  test('HealthGoals value equality', () {
    const a = HealthGoals(bpSystolic: 130, bpDiastolic: 80, totalCholesterol: 4.5, stepsPerDay: 6000, targetWeightKg: 78, dietNote: 'Less salt');
    const b = HealthGoals(bpSystolic: 130, bpDiastolic: 80, totalCholesterol: 4.5, stepsPerDay: 6000, targetWeightKg: 78, dietNote: 'Less salt');
    expect(a, equals(b));
  });
}
