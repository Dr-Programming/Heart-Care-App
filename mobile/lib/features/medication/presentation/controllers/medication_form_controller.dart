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

  /// Set when the medication itself saved successfully but scheduling its
  /// reminder notifications afterward threw (e.g. a missing/denied
  /// `SCHEDULE_EXACT_ALARM` permission on the device). The write already
  /// happened by this point — `save()` deliberately does not fail the whole
  /// operation for a reminder-scheduling problem, since that previously left
  /// a genuinely-saved medication reporting as failed, inviting a retry that
  /// would silently create a duplicate. The UI surfaces this as a soft
  /// warning instead of a save error.
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

  /// Sensibly spaced suggestions, keyed by how many slots the frequency wants.
  ///
  /// Distinct values are not cosmetic. `scheduledDosesFor` and
  /// `computeAdherence` both match a dose log to a slot by `scheduledTime`
  /// alone, so two slots at the same time collapse into one: a single log
  /// satisfies both, and the day's denominator silently halves. `TimeListField`
  /// also deletes by value, so removing one of two identical chips removes
  /// both. The exact hours are not spec-mandated — only that they differ.
  static const Map<int, List<String>> _suggestedTimes = <int, List<String>>{
    1: <String>['08:00'],
    2: <String>['08:00', '20:00'],
    3: <String>['08:00', '14:00', '20:00'],
  };

  /// Soft suggestion only (never enforced) — mirrors the backend's
  /// deliberate non-validation of schedule-time count against frequency.
  void setFrequency(MedicationFrequency value) {
    final int suggested = value.suggestedTimeCount;
    final List<String> times = <String>[...state.scheduleTimes];

    for (final String candidate in _suggestedTimes[suggested] ?? const <String>[]) {
      if (times.length >= suggested) break;
      // Never re-add a time the user already has: the defaults for N slots
      // hold N distinct values, so skipping the ones already present still
      // leaves enough to reach `suggested`.
      if (times.contains(candidate)) continue;
      times.add(candidate);
    }

    state = state.copyWith(frequency: value, scheduleTimes: times);
  }

  void setScheduleTimes(List<String> times) =>
      state = state.copyWith(scheduleTimes: times, scheduleError: validateScheduleTimes(times));

  /// Re-validates every field against the current state, updating `state`'s
  /// three error fields either way, and returns whether all of them passed.
  ///
  /// Split out of [save] so `MedicationFormScreen`'s Save button can run the
  /// same up-to-date check before pushing `ReviewMedicationScreen` (M3 Figma
  /// rework) without duplicating the validator calls: a field the user never
  /// touched never ran its `onChanged` validator, so it must still be
  /// re-checked at submit time — exactly what `save()` always did before this
  /// method existed, and still does, via this shared call.
  ///
  /// "As needed" (second Figma follow-up) is `frequency == custom` with an
  /// empty `scheduleTimes` — a deliberate, real state, not an unfinished
  /// form — so that one combination skips `validateScheduleTimes` entirely
  /// rather than failing it. `validateScheduleTimes` itself stays untouched:
  /// it has no notion of frequency and does not need one, since every other
  /// frequency must still require at least one time exactly as before.
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

  /// [caregiverSettings]/[instructions] are optional because they are owned
  /// by `CaregiverNotifyStore`/`MedicationInstructionsStore`, not this
  /// controller's own state (see those stores' doc comments) — the caller
  /// (`ReviewMedicationScreen`) passes the values it was handed down from
  /// `MedicationFormScreen`'s local `State`. Persisting them here, after the
  /// medication write above succeeds, is what makes them work in ADD mode
  /// (third Figma follow-up): there is no `clientRecordId` to key either
  /// store by until this exact point, when `repository.add` returns one for
  /// the first time. A failure persisting either is treated the same way as
  /// a reminder-scheduling failure above — non-fatal, since the medication
  /// itself is already saved by this point and must not be reported as
  /// failed over a problem with a local-only, best-effort side field.
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
      // The write itself failed — nothing was saved, so this is the one
      // case save() still reports as a failure.
      state = state.copyWith(isSaving: false);
      rethrow;
    }

    // From here on the medication is already persisted. A reminder-
    // scheduling failure (e.g. a missing SCHEDULE_EXACT_ALARM permission)
    // must not make save() report failure — that previously left a
    // genuinely-saved medication looking like nothing happened, inviting a
    // retry that would silently duplicate it.
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
        // Best-effort, local-only side field — see this method's doc comment.
      }
    }
    if (instructions != null) {
      try {
        await ref
            .read(medicationInstructionsStoreProvider)
            .set(medication.clientRecordId, instructions);
      } catch (_) {
        // Best-effort, local-only side field — see this method's doc comment.
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

/// Auto-disposed, and that is load-bearing rather than a micro-optimisation.
///
/// A form's state is scoped to one visit to the form. Kept alive across
/// visits, editing medication A and then opening "Add" would prefill A's name
/// and dose *and* still hold `_editingClientRecordId`, so Save would silently
/// call `edit(A)` instead of `add()`. `saved` would also stay true forever
/// after the first successful save, which breaks `MedicationFormScreen`'s
/// close-on-save `ref.listen` (it is gated on `!previous.saved`) on every
/// visit after the first.
///
/// `MedicationFormScreen` holds the only listener for as long as it is
/// mounted — see its `initState` — so a fresh instance is built each time the
/// screen is entered.
final NotifierProvider<MedicationFormController, MedicationFormState>
medicationFormControllerProvider =
    NotifierProvider.autoDispose<MedicationFormController, MedicationFormState>(
      MedicationFormController.new,
    );
