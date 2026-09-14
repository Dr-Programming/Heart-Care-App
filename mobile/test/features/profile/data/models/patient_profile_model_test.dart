import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';

void main() {
  test('fromJson parses the all-null skeleton without throwing', () {
    final model = PatientProfileModel.fromJson(const <String, dynamic>{
      'birthYear': null, 'preferredLanguage': null, 'heightCm': null,
      'chdStage': null, 'diseaseHistory': null, 'comorbidities': <dynamic>[],
      'managementPlan': null, 'goals': null,
    });
    expect(model.birthYear, isNull);
    expect(model.comorbidities, isEmpty);
    expect(model.goals, isNull);
  });

  test('fromJson parses a fully populated profile', () {
    final model = PatientProfileModel.fromJson(const <String, dynamic>{
      'birthYear': 1968, 'preferredLanguage': 'am', 'heightCm': 172.0,
      'chdStage': 'Coronary artery disease', 'diseaseHistory': 'Diagnosed 2019.',
      'comorbidities': <dynamic>['diabetes', 'hypertension'],
      'managementPlan': 'Aspirin, statin.',
      'goals': <String, dynamic>{
        'bpSystolic': 130, 'bpDiastolic': 80, 'totalCholesterol': 4.5,
        'stepsPerDay': 6000, 'targetWeightKg': 78.0, 'dietNote': 'Less salt',
      },
    });
    expect(model.birthYear, 1968);
    expect(model.comorbidities, <String>['diabetes', 'hypertension']);
    expect(model.goals?.bpSystolic, 130);
    expect(model.goals?.dietNote, 'Less salt');
  });

  test('toJson sends every field, including nulls', () {
    final model = PatientProfileModel.fromDomain(PatientProfile.empty('u1').copyWith(birthYear: 1968));
    final json = model.toJson();
    expect(json.containsKey('birthYear'), isTrue);
    expect(json.containsKey('preferredLanguage'), isTrue);
    expect(json.containsKey('heightCm'), isTrue);
    expect(json.containsKey('chdStage'), isTrue);
    expect(json.containsKey('diseaseHistory'), isTrue);
    expect(json.containsKey('comorbidities'), isTrue);
    expect(json.containsKey('managementPlan'), isTrue);
    expect(json.containsKey('goals'), isTrue);
    expect(json['birthYear'], 1968);
  });

  test('toDomain and fromDomain round-trip', () {
    const profile = PatientProfile(
      userId: 'u1', birthYear: 1968, preferredLanguage: 'en', heightCm: 172,
      chdStage: 'Coronary artery disease', diseaseHistory: null,
      comorbidities: <String>['diabetes'], managementPlan: null,
      goals: HealthGoals(stepsPerDay: 6000), updatedAt: null,
    );
    final roundTripped = PatientProfileModel.fromDomain(profile).toDomain('u1');
    expect(roundTripped.birthYear, profile.birthYear);
    expect(roundTripped.comorbidities, profile.comorbidities);
    expect(roundTripped.goals?.stepsPerDay, 6000);
  });
}
