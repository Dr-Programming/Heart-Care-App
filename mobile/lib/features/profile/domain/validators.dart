class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

class ProfileValidators {
  static ValidationResult birthYear(int? year) {
    if (year == null) return const ValidationResult.valid();
    if (year < 1900 || year > 2100) {
      return const ValidationResult.invalid(
        'Birth year must be between 1900 and 2100',
      );
    }
    return const ValidationResult.valid();
  }

  static ValidationResult heightCm(double? height) {
    if (height == null) return const ValidationResult.valid();
    if (height < 50 || height > 250) {
      return const ValidationResult.invalid(
        'Height must be between 50 and 250 cm',
      );
    }
    return const ValidationResult.valid();
  }

  static ValidationResult chdStage(String? stage) {
    if (stage == null) return const ValidationResult.valid();
    if (stage.length > 50) {
      return const ValidationResult.invalid(
        'Diagnosis must be 50 characters or fewer',
      );
    }
    return const ValidationResult.valid();
  }

  static ValidationResult nonNegative(num? value, String fieldName) {
    if (value == null) return const ValidationResult.valid();
    if (value < 0) {
      return ValidationResult.invalid('$fieldName cannot be negative');
    }
    return const ValidationResult.valid();
  }
}