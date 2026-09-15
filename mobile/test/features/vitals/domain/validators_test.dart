import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/validators.dart';

void main() {
  group('validateVitalValues', () {
    test('a BP with systolic <= diastolic is rejected', () {
      final Map<String, String> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 80, 'diastolic': 90},
      );
      expect(errors['diastolic'], 'vitals.validation.systolicMustExceedDiastolic');
    });

    test('a valid BP has no errors', () {
      final Map<String, String> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 120, 'diastolic': 80},
      );
      expect(errors, isEmpty);
    });

    test('a missing key is rejected', () {
      final Map<String, String> errors = validateVitalValues(
        VitalType.glucose,
        <String, double?>{'glucose': null},
      );
      expect(errors['glucose'], 'vitals.validation.required');
    });

    test('a value above the maximum is rejected as too high', () {
      final Map<String, String> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 400},
      );
      expect(errors['heartRate'], 'vitals.validation.tooHigh');
    });

    test('a value below the minimum is rejected as too low', () {
      final Map<String, String> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 5},
      );
      expect(errors['heartRate'], 'vitals.validation.tooLow');
    });
  });

  group('validateVitalNote', () {
    test('null and empty are valid', () {
      expect(validateVitalNote(null), isNull);
      expect(validateVitalNote(''), isNull);
    });

    test('over 500 characters is rejected', () {
      expect(validateVitalNote('a' * 501), 'vitals.validation.noteTooLong');
    });
  });
}
