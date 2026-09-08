import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';

/// In-progress wizard state, held only in memory. Nothing here is persisted
/// until the wizard finishes or is explicitly skipped — the profile is
/// written once, not per-step (see the M2 design spec).
class OnboardingState {
  final int? birthYear;
  final double? heightCm;
  final String preferredLanguage;
  final String? chdStage;
  final List<String> comorbidities;
  final String? diseaseHistory;
  final String? managementPlan;
  final HealthGoals? goals;

  /// Reminder preferences captured in step 3. These are device-local
  /// Preferences rows (`PreferenceKeys.notificationsEnabled` /
  /// `.symptomPromptTime`), not part of `PatientProfile` — the backend has
  /// no notification fields, so [toPatientProfile] intentionally does not
  /// include them. They are written separately via `ReminderPrefs` at the
  /// same finish/skip moment the profile is saved.
  final bool notificationsEnabled;
  final String symptomPromptTime;

  const OnboardingState({
    this.birthYear,
    this.heightCm,
    this.preferredLanguage = 'en',
    this.chdStage,
    this.comorbidities = const [],
    this.diseaseHistory,
    this.managementPlan,
    this.goals,
    this.notificationsEnabled = true,
    this.symptomPromptTime = '19:30',
  });

  OnboardingState copyWith({
    int? birthYear,
    double? heightCm,
    String? preferredLanguage,
    String? chdStage,
    List<String>? comorbidities,
    String? diseaseHistory,
    String? managementPlan,
    HealthGoals? goals,
    bool? notificationsEnabled,
    String? symptomPromptTime,
  }) {
    return OnboardingState(
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      chdStage: chdStage ?? this.chdStage,
      comorbidities: comorbidities ?? this.comorbidities,
      diseaseHistory: diseaseHistory ?? this.diseaseHistory,
      managementPlan: managementPlan ?? this.managementPlan,
      goals: goals ?? this.goals,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      symptomPromptTime: symptomPromptTime ?? this.symptomPromptTime,
    );
  }

  PatientProfile toPatientProfile() {
    return PatientProfile(
      birthYear: birthYear,
      preferredLanguage: preferredLanguage,
      heightCm: heightCm,
      chdStage: chdStage,
      diseaseHistory: diseaseHistory,
      comorbidities: comorbidities,
      managementPlan: managementPlan,
      goals: goals,
    );
  }
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void updatePersonalDetails({
    int? birthYear,
    double? heightCm,
    String? preferredLanguage,
  }) {
    state = state.copyWith(
      birthYear: birthYear,
      heightCm: heightCm,
      preferredLanguage: preferredLanguage,
    );
  }

  void updateMedicalProfile({
    String? chdStage,
    List<String>? comorbidities,
    String? diseaseHistory,
    String? managementPlan,
  }) {
    state = state.copyWith(
      chdStage: chdStage,
      comorbidities: comorbidities,
      diseaseHistory: diseaseHistory,
      managementPlan: managementPlan,
    );
  }

  void updateGoals(HealthGoals goals) {
    state = state.copyWith(goals: goals);
  }

  /// Captures the reminder toggle and symptom check-in time chosen in step
  /// 3. Written to Preferences (not the profile) at finish/skip time — see
  /// the doc comment on [OnboardingState.notificationsEnabled].
  void updateReminders({
    bool? notificationsEnabled,
    String? symptomPromptTime,
  }) {
    state = state.copyWith(
      notificationsEnabled: notificationsEnabled,
      symptomPromptTime: symptomPromptTime,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);