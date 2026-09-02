class ValidationResult {
  final bool isValid;

  /// A translation key, not literal text — callers `.tr()` it. Keeping
  /// English out of the domain layer is what lets the same validator serve
  /// both languages (FR-LOC-002).
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

class ProfileValidators {
  static ValidationResult birthYear(int? year) {
    if (year == null) return const ValidationResult.valid();
    if (year < 1900 || year > 2100) {
      return const ValidationResult.invalid('profile.errors.birthYearRange');
    }
    return const ValidationResult.valid();
  }

  static ValidationResult heightCm(double? height) {
    if (height == null) return const ValidationResult.valid();
    if (height < 50 || height > 250) {
      return const ValidationResult.invalid('profile.errors.heightRange');
    }
    return const ValidationResult.valid();
  }

  static ValidationResult chdStage(String? stage) {
    if (stage == null) return const ValidationResult.valid();
    if (stage.length > 50) {
      return const ValidationResult.invalid('profile.errors.diagnosisLength');
    }
    return const ValidationResult.valid();
  }

  static ValidationResult nonNegative(num? value) {
    if (value == null) return const ValidationResult.valid();
    if (value < 0) {
      return const ValidationResult.invalid('profile.errors.negativeValue');
    }
    return const ValidationResult.valid();
  }
}
