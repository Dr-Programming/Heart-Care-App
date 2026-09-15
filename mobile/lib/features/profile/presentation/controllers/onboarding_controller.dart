import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/health_goals.dart';
import '../../domain/entities/patient_profile.dart';
import '../../profile_providers.dart';

class OnboardingState {
  const OnboardingState({
    this.step = 0,
    this.name,
    this.birthYear,
    this.heightCm,
    this.preferredLanguage,
    this.diagnosisSelection = const <String>{},
    this.comorbidities = const <String>{},
    this.otherComorbidity,
    this.medicationReminderOn = true,
    this.medicationReminderTime,
    this.vitalsReminderOn = true,
    this.vitalsReminderTime,
    this.symptomReminderOn = true,
    this.symptomReminderTime,
    this.notificationsOn = true,
  });

  final int step;

  final String? name;
  final int? birthYear;
  final double? heightCm;
  final String? preferredLanguage;

  final Set<String> diagnosisSelection;

  final Set<String> comorbidities;
  final String? otherComorbidity;

  final bool medicationReminderOn;
  final String? medicationReminderTime;
  final bool vitalsReminderOn;
  final String? vitalsReminderTime;
  final bool symptomReminderOn;
  final String? symptomReminderTime;
  final bool notificationsOn;

  OnboardingState copyWith({
    int? step,
    String? name,
    int? birthYear,
    double? heightCm,
    String? preferredLanguage,
    Set<String>? diagnosisSelection,
    Set<String>? comorbidities,
    String? otherComorbidity,
    bool? medicationReminderOn,
    String? medicationReminderTime,
    bool? vitalsReminderOn,
    String? vitalsReminderTime,
    bool? symptomReminderOn,
    String? symptomReminderTime,
    bool? notificationsOn,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      name: name ?? this.name,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      diagnosisSelection: diagnosisSelection ?? this.diagnosisSelection,
      comorbidities: comorbidities ?? this.comorbidities,
      otherComorbidity: otherComorbidity ?? this.otherComorbidity,
      medicationReminderOn: medicationReminderOn ?? this.medicationReminderOn,
      medicationReminderTime:
          medicationReminderTime ?? this.medicationReminderTime,
      vitalsReminderOn: vitalsReminderOn ?? this.vitalsReminderOn,
      vitalsReminderTime: vitalsReminderTime ?? this.vitalsReminderTime,
      symptomReminderOn: symptomReminderOn ?? this.symptomReminderOn,
      symptomReminderTime: symptomReminderTime ?? this.symptomReminderTime,
      notificationsOn: notificationsOn ?? this.notificationsOn,
    );
  }
}

class OnboardingController extends Notifier<OnboardingState> {
  static const String _needsOnboardingKey = 'auth_needs_onboarding';

  static const String _medicationReminderEnabledKey =
      'profile_medication_reminder_enabled';
  static const String _vitalsReminderEnabledKey =
      'profile_vitals_reminder_enabled';
  static const String _symptomReminderEnabledKey =
      'profile_symptom_reminder_enabled';

  @override
  OnboardingState build() => const OnboardingState();

  void setName(String? name) => state = state.copyWith(name: name);
  void setBirthYear(int? year) => state = state.copyWith(birthYear: year);
  void setHeightCm(double? cm) => state = state.copyWith(heightCm: cm);
  void setPreferredLanguage(String? language) =>
      state = state.copyWith(preferredLanguage: language);
  void setDiagnosisSelection(Set<String> value) =>
      state = state.copyWith(diagnosisSelection: value);
  void setComorbidities(Set<String> value) =>
      state = state.copyWith(comorbidities: value);
  void setOtherComorbidity(String? value) =>
      state = state.copyWith(otherComorbidity: value);
  void setMedicationReminder(bool on) =>
      state = state.copyWith(medicationReminderOn: on);
  void setMedicationReminderTime(String? time) =>
      state = state.copyWith(medicationReminderTime: time);
  void setVitalsReminder(bool on) =>
      state = state.copyWith(vitalsReminderOn: on);
  void setVitalsReminderTime(String? time) =>
      state = state.copyWith(vitalsReminderTime: time);
  void setSymptomReminder(bool on) =>
      state = state.copyWith(symptomReminderOn: on);
  void setSymptomReminderTime(String? time) =>
      state = state.copyWith(symptomReminderTime: time);
  void setNotificationsOn(bool on) =>
      state = state.copyWith(notificationsOn: on);

  void next() {
    if (state.step < 2) state = state.copyWith(step: state.step + 1);
  }

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1);
  }

  Future<void> finish() async {
    await _writeProfile();
    await _clearNeedsOnboarding();
  }

  Future<void> skip() async {
    await _writeProfile();
    await _clearNeedsOnboarding();
  }

  Future<void> _writeProfile() async {
    final cachedUser = await ref
        .read(appDatabaseProvider)
        .cachedUserDao
        .current();
    final userId = cachedUser?.id ?? '';
    final allComorbidities = <String>{
      ...state.diagnosisSelection,
      ...state.comorbidities,
      if (state.otherComorbidity != null &&
          state.otherComorbidity!.trim().isNotEmpty)
        state.otherComorbidity!.trim(),
    };
    final profile = PatientProfile.empty(userId).copyWith(
      birthYear: state.birthYear,
      preferredLanguage: state.preferredLanguage,
      heightCm: state.heightCm,
      chdStage: 'Coronary artery disease',
      comorbidities: allComorbidities.toList(growable: false),
      goals: const HealthGoals(),
    );
    await ref.read(profileRepositoryProvider).saveProfile(profile);
    await _writeReminderPreferences();
  }

  Future<void> _writeReminderPreferences() async {
    final preferencesDao = ref.read(appDatabaseProvider).preferencesDao;
    await preferencesDao.set(
      PreferenceKeys.notificationsEnabled,
      state.notificationsOn.toString(),
    );
    await preferencesDao.set(
      PreferenceKeys.symptomPromptTime,
      state.symptomReminderTime ?? '19:30',
    );
    await preferencesDao.set(
      _medicationReminderEnabledKey,
      state.medicationReminderOn.toString(),
    );
    await preferencesDao.set(
      _vitalsReminderEnabledKey,
      state.vitalsReminderOn.toString(),
    );
    await preferencesDao.set(
      _symptomReminderEnabledKey,
      state.symptomReminderOn.toString(),
    );
  }

  Future<void> _clearNeedsOnboarding() async {
    final preferencesDao = ref.read(appDatabaseProvider).preferencesDao;
    await preferencesDao.set(_needsOnboardingKey, 'false');
  }
}

final NotifierProvider<OnboardingController, OnboardingState>
onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
