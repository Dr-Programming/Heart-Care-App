import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vital_type.dart';
import '../../domain/validators.dart';
import '../../vitals_providers.dart';
import 'vitals_history_controller.dart';
import 'vitals_list_controller.dart';
import 'vitals_trend_controller.dart';

class VitalFormState {
  const VitalFormState({
    this.valuesByType = const <VitalType, Map<String, double?>>{},
    this.errorsByType = const <VitalType, Map<String, String>>{},
    DateTime? measuredAt,
    this.note,
    this.isSaving = false,
    this.generalError,
    this.saved = false,
  }) : _measuredAt = measuredAt;

  final Map<VitalType, Map<String, double?>> valuesByType;
  final Map<VitalType, Map<String, String>> errorsByType;
  final DateTime? _measuredAt;
  final String? note;
  final bool isSaving;
  final String? generalError;
  final bool saved;

  DateTime get measuredAt => _measuredAt ?? DateTime.now();

  double? valueFor(VitalType type, String key) => valuesByType[type]?[key];

  VitalFormState copyWith({
    Map<VitalType, Map<String, double?>>? valuesByType,
    Map<VitalType, Map<String, String>>? errorsByType,
    DateTime? measuredAt,
    String? note,
    bool? isSaving,
    String? generalError,
    bool? saved,
    bool clearGeneralError = false,
  }) {
    return VitalFormState(
      valuesByType: valuesByType ?? this.valuesByType,
      errorsByType: errorsByType ?? this.errorsByType,
      measuredAt: measuredAt ?? _measuredAt,
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      generalError: clearGeneralError
          ? null
          : (generalError ?? this.generalError),
      saved: saved ?? this.saved,
    );
  }
}

class VitalFormController extends Notifier<VitalFormState> {
  @override
  VitalFormState build() => const VitalFormState();

  void updateValue(VitalType type, String key, double? value) {
    final Map<String, double?> current = <String, double?>{
      ...?state.valuesByType[type],
      key: value,
    };
    state = state.copyWith(
      valuesByType: <VitalType, Map<String, double?>>{
        ...state.valuesByType,
        type: current,
      },
      errorsByType: <VitalType, Map<String, String>>{...state.errorsByType}
        ..remove(type),
      clearGeneralError: true,
    );
  }

  void updateMeasuredAt(DateTime value) {
    state = state.copyWith(measuredAt: value);
  }

  void updateNote(String value) {
    state = state.copyWith(note: value);
  }

  bool _isBlank(Map<String, double?>? values) =>
      values == null || values.values.every((double? v) => v == null);

  Future<bool> save() async {
    final Map<VitalType, Map<String, String>> errorsByType =
        <VitalType, Map<String, String>>{};
    final List<VitalType> typesToSubmit = <VitalType>[];

    for (final VitalType type in VitalType.values) {
      final Map<String, double?>? values = state.valuesByType[type];
      if (_isBlank(values)) continue;
      final Map<String, String> errors = validateVitalValues(type, values!);
      if (errors.isNotEmpty) {
        errorsByType[type] = errors;
      } else {
        typesToSubmit.add(type);
      }
    }

    final String? noteError = validateVitalNote(state.note);

    if (errorsByType.isNotEmpty || noteError != null) {
      state = state.copyWith(
        errorsByType: errorsByType,
        generalError: noteError,
      );
      return false;
    }

    if (typesToSubmit.isEmpty) {
      state = state.copyWith(generalError: 'vitals.log.nothingToSave');
      return false;
    }

    state = state.copyWith(isSaving: true, clearGeneralError: true);
    try {
      final String? note = (state.note?.isEmpty ?? true) ? null : state.note;
      for (final VitalType type in typesToSubmit) {
        final Map<String, double?> raw = state.valuesByType[type]!;
        final Map<String, double> values = raw.map(
          (String key, double? value) => MapEntry<String, double>(key, value!),
        );

        await ref
            .read(logVitalProvider)
            .call(
              type: type,
              values: values,
              measuredAt: state.measuredAt,
              note: note,
            );
      }

      ref.invalidate(vitalsListControllerProvider);
      ref.invalidate(vitalsHistoryControllerProvider);
      for (final VitalType type in typesToSubmit) {
        ref.invalidate(vitalsTrendControllerProvider(type));
      }
      state = state.copyWith(saved: true);
      return true;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final NotifierProvider<VitalFormController, VitalFormState>
vitalFormControllerProvider = NotifierProvider.autoDispose(
  VitalFormController.new,
);
