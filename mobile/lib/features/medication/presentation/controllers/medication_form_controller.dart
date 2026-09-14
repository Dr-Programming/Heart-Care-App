import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/caregiver_notify_store.dart';
import '../../data/medication_instructions_store.dart';
import '../../domain/entities/medication.dart';
import '../../domain/validators.dart';
import '../../medication_providers.dart';
import 'medication_list_controller.dart';

const Object _sentinel = Object();

class MedicationFormState {
  const MedicationFormState({
    this.name = '',
    this.doseMg = '',
    this.frequency = MedicationFrequency.onceDaily,
    this.scheduleTimes = const <String>[],
    this.nameError,
    this.doseError,
    this.scheduleError,
    this.isSaving = false,
    this.saved = false,
    this.reminderSchedulingFailed = false,
  });

  final String name;
  final String doseMg;
  final MedicationFrequency frequency;
  final List<String> scheduleTimes;
  final String? nameError;
  final String? doseError;
  final String? scheduleError;
  final bool isSaving;
  final bool saved;

  final bool reminderSchedulingFailed;

  bool get isValid => nameError == null && doseError == null && scheduleError == null;

  MedicationFormState copyWith({
    String? name,
    String? doseMg,
    MedicationFrequency? frequency,
    List<String>? scheduleTimes,
    Object? nameError = _sentinel,
    Object? doseError = _sentinel,
    Object? scheduleError = _sentinel,
    bool? isSaving,
    bool? saved,
    bool? reminderSchedulingFailed,
  }) {
    return MedicationFormState(
      name: name ?? this.name,
      doseMg: doseMg ?? this.doseMg,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      nameError: identical(nameError, _sentinel) ? this.nameError : nameError as String?,
      doseError: identical(doseError, _sentinel) ? this.doseError : doseError as String?,
      scheduleError: identical(scheduleError, _sentinel) ? this.scheduleError : scheduleError as String?,
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
      reminderSchedulingFailed: reminderSchedulingFailed ?? this.reminderSchedulingFailed,
    );
  }
}

class MedicationFormController extends Notifier<MedicationFormState> {
  String? _editingClientRecordId;

  @override
  MedicationFormState build() => const MedicationFormState();

  void loadForEdit(Medication medication) {
    _editingClientRecordId = medication.clientRecordId;
    state = MedicationFormState(
      name: medication.name,
      doseMg: medication.doseMg.toString(),
      frequency: medication.frequency,
      scheduleTimes: medication.scheduleTimes,
    );
  }

  void setName(String value) =>
      state = state.copyWith(name: value, nameError: validateMedicationName(value));

  void setDoseMg(String value) =>
      state = state.copyWith(doseMg: value, doseError: validateDoseMg(value));

  static const Map<int, List<String>> _suggestedTimes = <int, List<String>>{
    1: <String>['08:00'],
    2: <String>['08:00', '20:00'],
    3: <String>['08:00', '14:00', '20:00'],
  };

  void setFrequency(MedicationFrequency value) {
    final int suggested = value.suggestedTimeCount;
    final List<String> times = <String>[...state.scheduleTimes];

    for (final String candidate in _suggestedTimes[suggested] ?? const <String>[]) {
      if (times.length >= suggested) break;

      if (times.contains(candidate)) continue;
      times.add(candidate);
    }

    state = state.copyWith(frequency: value, scheduleTimes: times);
  }

  void setScheduleTimes(List<String> times) =>
      state = state.copyWith(scheduleTimes: times, scheduleError: validateScheduleTimes(times));

  bool validate() {
    final String? nameError = validateMedicationName(state.name);
    final String? doseError = validateDoseMg(state.doseMg);
    final bool isAsNeeded =
        state.frequency == MedicationFrequency.custom && state.scheduleTimes.isEmpty;
    final String? scheduleError =
        isAsNeeded ? null : validateScheduleTimes(state.scheduleTimes);
    state = state.copyWith(nameError: nameError, doseError: doseError, scheduleError: scheduleError);
    return nameError == null && doseError == null && scheduleError == null;
  }

  Future<bool> save({
    CaregiverNotifySettings? caregiverSettings,
    MedicationInstructions? instructions,
  }) async {
    if (!validate()) return false;

    state = state.copyWith(isSaving: true);
    final Medication medication;
    try {
      final repository = ref.read(medicationRepositoryProvider);
      final double doseValue = double.parse(state.doseMg);

      if (_editingClientRecordId == null) {
        medication = await repository.add(
          name: state.name.trim(),
          doseMg: doseValue,
          frequency: state.frequency,
          scheduleTimes: state.scheduleTimes,
        );
      } else {
        final Medication current = (await repository.allMedications(includeInactive: true))
            .firstWhere((Medication m) => m.clientRecordId == _editingClientRecordId);
        medication = await repository.edit(
          current.copyWith(
            name: state.name.trim(),
            doseMg: doseValue,
            frequency: state.frequency,
            scheduleTimes: state.scheduleTimes,
          ),
        );
      }
    } catch (_) {

      state = state.copyWith(isSaving: false);
      rethrow;
    }

    bool reminderSchedulingFailed = false;
    try {
      await ref.read(medicationNotificationsProvider).scheduleFor(medication);
    } catch (_) {
      reminderSchedulingFailed = true;
    }

    if (caregiverSettings != null) {
      try {
        await ref
            .read(caregiverNotifyStoreProvider)
            .set(medication.clientRecordId, caregiverSettings);
      } catch (_) {

      }
    }
    if (instructions != null) {
      try {
        await ref
            .read(medicationInstructionsStoreProvider)
            .set(medication.clientRecordId, instructions);
      } catch (_) {

      }
    }

    ref.invalidate(medicationListControllerProvider);
    state = state.copyWith(
      isSaving: false,
      saved: true,
      reminderSchedulingFailed: reminderSchedulingFailed,
    );
    return true;
  }
}

final NotifierProvider<MedicationFormController, MedicationFormState>
medicationFormControllerProvider =
    NotifierProvider.autoDispose<MedicationFormController, MedicationFormState>(
      MedicationFormController.new,
    );
