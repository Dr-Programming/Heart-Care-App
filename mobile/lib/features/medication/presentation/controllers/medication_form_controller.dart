import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }
}

/// Add is the default; [loadForEdit] switches it to editing that medication.
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

  /// Soft suggestion only (never enforced) — mirrors the backend's
  /// deliberate non-validation of schedule-time count against frequency.
  void setFrequency(MedicationFrequency value) {
    final int suggested = value.suggestedTimeCount;
    final List<String> times = state.scheduleTimes.length >= suggested
        ? state.scheduleTimes
        : <String>[
            ...state.scheduleTimes,
            for (int i = state.scheduleTimes.length; i < suggested; i++) '08:00',
          ];
    state = state.copyWith(frequency: value, scheduleTimes: times);
  }

  void setScheduleTimes(List<String> times) =>
      state = state.copyWith(scheduleTimes: times, scheduleError: validateScheduleTimes(times));

  Future<bool> save() async {
    final String? nameError = validateMedicationName(state.name);
    final String? doseError = validateDoseMg(state.doseMg);
    final String? scheduleError = validateScheduleTimes(state.scheduleTimes);
    state = state.copyWith(nameError: nameError, doseError: doseError, scheduleError: scheduleError);
    if (nameError != null || doseError != null || scheduleError != null) return false;

    state = state.copyWith(isSaving: true);
    final repository = ref.read(medicationRepositoryProvider);
    final double doseValue = double.parse(state.doseMg);

    final Medication medication;
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

    await ref.read(medicationNotificationsProvider).scheduleFor(medication);
    ref.invalidate(medicationListControllerProvider);
    state = state.copyWith(isSaving: false, saved: true);
    return true;
  }
}

final NotifierProvider<MedicationFormController, MedicationFormState>
medicationFormControllerProvider =
    NotifierProvider<MedicationFormController, MedicationFormState>(
      MedicationFormController.new,
    );
