/// Bounds the server enforces (ActivityService), checked here so the patient
/// sees the problem in the form instead of the record being rejected at sync.
const int minDurationMinutes = 1;
const int maxDurationMinutes = 1440;
const int maxSteps = 100000;

String? validateDurationMinutes(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return 'activity.errors.durationRequired';
  final int? minutes = int.tryParse(trimmed);
  if (minutes == null) return 'activity.errors.durationInvalid';
  if (minutes < minDurationMinutes || minutes > maxDurationMinutes) {
    return 'activity.errors.durationRange';
  }
  return null;
}

String? validateSteps(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final int? steps = int.tryParse(trimmed);
  if (steps == null) return 'activity.errors.stepsInvalid';
  if (steps < 0 || steps > maxSteps) return 'activity.errors.stepsRange';
  return null;
}

String? validateActivityNote(String value) =>
    value.length > 500 ? 'activity.errors.noteTooLong' : null;
