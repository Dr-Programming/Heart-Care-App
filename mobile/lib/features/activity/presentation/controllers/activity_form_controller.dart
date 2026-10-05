import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity_providers.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/validators.dart';
import 'activity_overview_controller.dart';

class ActivityFormState {
  const ActivityFormState({
    this.type = ActivityType.walking,
    this.intensity = Intensity.moderate,
    this.duration = '',
    this.steps = '',
    this.note = '',
    this.durationError,
    this.stepsError,
    this.noteError,
    this.isSaving = false,
  });

  final ActivityType type;
  final Intensity intensity;
  final String duration;
  final String steps;
  final String note;
  final String? durationError;
  final String? stepsError;
  final String? noteError;
  final bool isSaving;

  /// Something was typed and not yet saved.
  bool get isDirty =>
      !isSaving &&
      (duration.trim().isNotEmpty ||
          steps.trim().isNotEmpty ||
          note.trim().isNotEmpty);

  ActivityFormState copyWith({
    ActivityType? type,
    Intensity? intensity,
    String? duration,
    String? steps,
    String? note,
    String? Function()? durationError,
    String? Function()? stepsError,
    String? Function()? noteError,
    bool? isSaving,
  }) {
    return ActivityFormState(
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      duration: duration ?? this.duration,
      steps: steps ?? this.steps,
      note: note ?? this.note,
      durationError: durationError == null
          ? this.durationError
          : durationError(),
      stepsError: stepsError == null ? this.stepsError : stepsError(),
      noteError: noteError == null ? this.noteError : noteError(),
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class ActivityFormController extends Notifier<ActivityFormState> {
  @override
  ActivityFormState build() => const ActivityFormState();

  void setType(ActivityType value) => state = state.copyWith(type: value);

  void setIntensity(Intensity value) =>
      state = state.copyWith(intensity: value);

  void setDuration(String value) =>
      state = state.copyWith(duration: value, durationError: () => null);

  void setSteps(String value) =>
      state = state.copyWith(steps: value, stepsError: () => null);

  void setNote(String value) =>
      state = state.copyWith(note: value, noteError: () => null);

  /// Returns true once the entry is saved on the phone.
  Future<bool> save() async {
    final String? durationError = validateDurationMinutes(state.duration);
    final String? stepsError = validateSteps(state.steps);
    final String? noteError = validateActivityNote(state.note);
    state = state.copyWith(
      durationError: () => durationError,
      stepsError: () => stepsError,
      noteError: () => noteError,
    );
    if (durationError != null || stepsError != null || noteError != null) {
      return false;
    }

    state = state.copyWith(isSaving: true);
    try {
      final String note = state.note.trim();
      await ref
          .read(activityRepositoryProvider)
          .log(
            type: state.type,
            durationMinutes: int.parse(state.duration.trim()),
            intensity: state.intensity,
            steps: state.steps.trim().isEmpty
                ? null
                : int.parse(state.steps.trim()),
            note: note.isEmpty ? null : note,
          );
    } finally {
      state = state.copyWith(isSaving: false);
    }
    ref.invalidate(activityOverviewControllerProvider);
    // Saved: nothing left to lose, so leaving no longer asks.
    state = const ActivityFormState();
    return true;
  }
}

final NotifierProvider<ActivityFormController, ActivityFormState>
activityFormControllerProvider =
    NotifierProvider.autoDispose<ActivityFormController, ActivityFormState>(
      ActivityFormController.new,
    );
