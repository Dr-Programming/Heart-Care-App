import 'entities/medication.dart';

/// The server's limit (MedicationRequest `@DecimalMax`).
const double maxDoseMg = 10000;

/// The server's limit for a custom schedule.
const int maxCustomTimes = 12;

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
  if (parsed > maxDoseMg) return 'meds.errors.doseTooHigh';
  return null;
}

String? validateScheduleTimes(List<String> times) {
  if (times.isEmpty) return 'meds.errors.scheduleRequired';
  for (final String time in times) {
    if (!_timePattern.hasMatch(time)) return 'meds.errors.scheduleFormat';
  }
  return null;
}

/// The rules the server applies to a schedule, checked here so the patient
/// sees the problem in the form instead of the record being rejected at sync.
String? validateScheduleCount(
  List<String> times,
  MedicationFrequency frequency,
) {
  if (times.toSet().length != times.length) {
    return 'meds.errors.scheduleDuplicate';
  }
  return switch (frequency) {
    MedicationFrequency.onceDaily when times.length != 1 =>
      'meds.errors.scheduleCountOnce',
    MedicationFrequency.bid when times.length != 2 =>
      'meds.errors.scheduleCountBid',
    MedicationFrequency.tid when times.length != 3 =>
      'meds.errors.scheduleCountTid',
    MedicationFrequency.custom when times.length > maxCustomTimes =>
      'meds.errors.scheduleTooMany',
    _ => null,
  };
}
