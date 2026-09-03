import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/utils/ids.dart';

import '../../domain/bmi.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/validators.dart';
import '../../domain/vital_descriptors.dart';
import '../../vitals_providers.dart';

enum VitalFormStatus { idle, saving, saved }

/// Everything the log-a-reading screen needs to render.
class VitalFormState {
  const VitalFormState({
    required this.type,
    required this.rawValues,
    required this.measuredAt,
    this.note,
    this.fieldErrors = const <String, FieldError>{},
    this.crossFieldError,
    this.status = VitalFormStatus.idle,
    this.resultSeverity,
    this.resultFlagged,
    this.hints = const <String, String>{},
  });

  factory VitalFormState.initial(VitalType type) => VitalFormState(
    type: type,
    rawValues: const <String, String>{},
    measuredAt: DateTime.now(),
  );

  final VitalType type;
  final Map<String, String> rawValues;
  final DateTime measuredAt;
  final String? note;
  final Map<String, FieldError> fieldErrors;
  final FieldError? crossFieldError;
  final VitalFormStatus status;
  final Severity? resultSeverity;
  final bool? resultFlagged;
  final Map<String, String> hints;

  bool get isSaving => status == VitalFormStatus.saving;
  bool get isSaved => status == VitalFormStatus.saved;

  VitalFormState copyWith({
    Map<String, String>? rawValues,
    DateTime? measuredAt,
    String? note,
    Map<String, FieldError>? fieldErrors,
    FieldError? crossFieldError,
    bool clearCrossFieldError = false,
    VitalFormStatus? status,
    Severity? resultSeverity,
    bool? resultFlagged,
    Map<String, String>? hints,
  }) {
    return VitalFormState(
      type: type,
      rawValues: rawValues ?? this.rawValues,
      measuredAt: measuredAt ?? this.measuredAt,
      note: note ?? this.note,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      crossFieldError: clearCrossFieldError
          ? null
          : (crossFieldError ?? this.crossFieldError),
      status: status ?? this.status,
      resultSeverity: resultSeverity ?? this.resultSeverity,
      resultFlagged: resultFlagged ?? this.resultFlagged,
      hints: hints ?? this.hints,
    );
  }
}

class VitalFormController extends Notifier<VitalFormState> {
  @override
  VitalFormState build() {
    _loadHints(VitalType.bloodPressure);
    return VitalFormState.initial(VitalType.bloodPressure);
  }

  void selectType(VitalType type) {
    state = VitalFormState.initial(type);
    _loadHints(type);
  }

  Future<void> _loadHints(VitalType type) async {
    final VitalReading? latest = await ref.read(latestByTypeProvider)(type);
    // Bail if the user switched types again while this was in flight.
    if (latest == null || state.type != type) return;
    state = state.copyWith(
      hints: latest.values.map(
        (String k, double v) => MapEntry<String, String>(k, v.toString()),
      ),
    );
  }

  void setValue(String key, String rawText) {
    state = state.copyWith(
      rawValues: <String, String>{...state.rawValues, key: rawText},
    );
  }

  void setNote(String? note) => state = state.copyWith(note: note);

  void setMeasuredAt(DateTime measuredAt) =>
      state = state.copyWith(measuredAt: measuredAt);

  /// Returns true on success. On failure, [VitalFormState.fieldErrors] and/or
  /// [VitalFormState.crossFieldError] are populated for the UI to show.
  Future<bool> submit() async {
    final VitalDescriptor descriptor = vitalDescriptors[state.type]!;
    final Map<String, double?> parsed = <String, double?>{};
    final Map<String, FieldError> parseErrors = <String, FieldError>{};

    for (final String key in descriptor.requiredKeys) {
      final String raw = (state.rawValues[key] ?? '').trim();
      if (raw.isEmpty) {
        parsed[key] = null;
        continue;
      }
      final double? value = double.tryParse(raw);
      if (value == null) {
        parseErrors[key] = const FieldError('errors.invalidNumber');
      }
      parsed[key] = value;
    }

    final Map<String, FieldError> fieldErrors = <String, FieldError>{
      ...validateVitalValues(state.type, parsed),
      ...parseErrors, // a non-numeric entry always wins over "required"
    };

    FieldError? crossFieldError;
    if (fieldErrors.isEmpty && state.type == VitalType.bloodPressure) {
      crossFieldError = bloodPressureCrossFieldError(
        parsed['systolic']!,
        parsed['diastolic']!,
      );
    }

    if (fieldErrors.isNotEmpty || crossFieldError != null) {
      state = state.copyWith(
        fieldErrors: fieldErrors,
        crossFieldError: crossFieldError,
        clearCrossFieldError: crossFieldError == null,
      );
      return false;
    }

    final Map<String, double> values = parsed.map(
      (String k, double? v) => MapEntry<String, double>(k, v!),
    );

    double? bmi;
    if (state.type == VitalType.weight) {
      final double? heightCm = await ref
          .read(vitalsRepositoryProvider)
          .patientHeightCm();
      bmi = calculateBmi(weightKg: values['weight']!, heightCm: heightCm);
    }

    final bool flagged = state.type == VitalType.weight
        ? (bmi != null && vitalFlagRanges['bmi']!.breached(bmi))
        : isVitalFlagged(values);

    final Severity severity = severityForVital(
      type: state.type.wire,
      values: values,
      bmi: bmi,
    );

    state = state.copyWith(status: VitalFormStatus.saving);

    await ref.read(logVitalProvider)(
      VitalReading(
        clientRecordId: newClientRecordId(),
        type: state.type,
        values: values,
        flagged: flagged,
        bmi: bmi,
        measuredAt: state.measuredAt,
        note: state.note,
      ),
    );

    state = state.copyWith(
      status: VitalFormStatus.saved,
      resultSeverity: severity,
      resultFlagged: flagged,
      fieldErrors: const <String, FieldError>{},
      clearCrossFieldError: true,
    );
    return true;
  }
}

final NotifierProvider<VitalFormController, VitalFormState>
vitalFormControllerProvider =
    NotifierProvider<VitalFormController, VitalFormState>(
      VitalFormController.new,
    );
