String? validateBirthYear(int? value) {
  if (value == null) return null;
  if (value < 1900 || value > 2100) return 'profile.errors.birthYearRange';
  return null;
}

String? validateHeightCm(double? value) {
  if (value == null) return null;
  if (value < 50 || value > 250) return 'profile.errors.heightRange';
  return null;
}

String? validateChdStageOverride(String value) {
  if (value.length > 50) return 'profile.errors.chdStageLength';
  return null;
}

String? validateGoalValue(num? value, {required String fieldKey}) {
  if (value == null) return null;
  if (value < 0) return 'profile.errors.goalNegative';
  return null;
}
