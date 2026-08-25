/// Pure form validation. Every non-null return is a `meds.errors.*`
/// translation key, never a rendered sentence.
final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String? validateMedicationName(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return 'meds.errors.nameRequired';
  if (trimmed.length > 255) return 'meds.errors.nameTooLong';
  return null;
}

String? validateDoseMg(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return 'meds.errors.doseRequired';
  final double? parsed = double.tryParse(trimmed);
  if (parsed == null) return 'meds.errors.doseInvalid';
  if (parsed <= 0) return 'meds.errors.dosePositive';
  return null;
}

String? validateScheduleTimes(List<String> times) {
  if (times.isEmpty) return 'meds.errors.scheduleRequired';
  for (final String time in times) {
    if (!_timePattern.hasMatch(time)) return 'meds.errors.scheduleFormat';
  }
  return null;
}
