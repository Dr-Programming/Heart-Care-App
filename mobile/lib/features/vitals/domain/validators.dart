import 'entities/vital_type.dart';
import 'vital_descriptors.dart';

Map<String, String> validateVitalValues(
  VitalType type,
  Map<String, double?> values,
) {
  final VitalDescriptor descriptor = vitalDescriptors[type]!;
  final Map<String, String> errors = <String, String>{};

  for (final VitalFieldSpec field in descriptor.fields) {
    final double? value = values[field.key];
    if (value == null) {
      errors[field.key] = 'vitals.validation.required';
      continue;
    }
    if (value < field.min) {
      errors[field.key] = 'vitals.validation.tooLow';
    } else if (value > field.max) {
      errors[field.key] = 'vitals.validation.tooHigh';
    }
  }

  if (type == VitalType.bloodPressure && errors.isEmpty) {
    final double systolic = values['systolic']!;
    final double diastolic = values['diastolic']!;
    if (systolic <= diastolic) {
      errors['diastolic'] = 'vitals.validation.systolicMustExceedDiastolic';
    }
  }

  return errors;
}

String? validateVitalNote(String? note) {
  if (note == null || note.isEmpty) return null;
  if (note.length > 500) return 'vitals.validation.noteTooLong';
  return null;
}
