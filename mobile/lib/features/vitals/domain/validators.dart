import 'entities/vital_type.dart';
import 'vital_descriptors.dart';

/// A field-level validation problem: a translation key plus any named args
/// the message needs (`errors.outOfRange`'s `{min}`/`{max}`). The domain
/// layer never resolves the key itself — no Flutter import here — the
/// presentation layer calls `.tr(namedArgs: ...)` on it.
class FieldError {
  const FieldError(this.key, [this.args = const <String, String>{}]);

  final String key;
  final Map<String, String> args;
}

/// Validates one reading's `values` against its type's descriptor:
/// structurally (every required key present) and physiologically (each
/// value inside its input-sanity range). Mirrors the backend's `400`
/// validation exactly (`docs/design/2026-07-10-vitals-design.md` §7).
///
/// Only iterates the descriptor's required keys, so an unexpected extra key
/// in [values] is silently ignored here — the remote datasource is what
/// guarantees only the required keys are ever sent (Task 7).
Map<String, FieldError> validateVitalValues(
  VitalType type,
  Map<String, double?> values,
) {
  final VitalDescriptor descriptor = vitalDescriptors[type]!;
  final Map<String, FieldError> errors = <String, FieldError>{};

  for (final String key in descriptor.requiredKeys) {
    final double? value = values[key];
    if (value == null) {
      errors[key] = const FieldError('errors.required');
      continue;
    }
    final ({num min, num max}) range = descriptor.ranges[key]!;
    if (value < range.min || value > range.max) {
      errors[key] = FieldError('errors.outOfRange', <String, String>{
        'min': range.min.toString(),
        'max': range.max.toString(),
      });
    }
  }
  return errors;
}

/// The one cross-field rule (backend §7): a blood-pressure reading's
/// systolic must exceed its diastolic. Call only after [validateVitalValues]
/// on the same values returns empty — this does not repeat the range check.
FieldError? bloodPressureCrossFieldError(double systolic, double diastolic) {
  return systolic > diastolic
      ? null
      : const FieldError('vitals.error.systolicMustExceedDiastolic');
}
