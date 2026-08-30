import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/validators.dart';

void main() {
  group('validateVitalValues', () {
    test('valid blood pressure has no errors', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 120, 'diastolic': 80},
      );
      expect(errors, isEmpty);
    });

    test('a missing required key is errors.required', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 120, 'diastolic': null},
      );
      expect(errors['diastolic']?.key, 'errors.required');
    });

    test('a value below range is errors.outOfRange with min/max args', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 5},
      );
      expect(errors['heartRate']?.key, 'errors.outOfRange');
      expect(errors['heartRate']?.args, <String, String>{'min': '20', 'max': '300'});
    });

    test('a value above range is errors.outOfRange', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 900},
      );
      expect(errors['heartRate']?.key, 'errors.outOfRange');
    });

    test('a value just inside the bound is valid', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 300},
      );
      expect(errors, isEmpty);
    });

    test('cholesterol validates all three keys independently', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.cholesterol,
        <String, double?>{'ldl': 40, 'hdl': 1.2, 'total': null},
      );
      expect(errors.keys, <String>{'ldl', 'total'});
      expect(errors['ldl']?.key, 'errors.outOfRange');
      expect(errors['total']?.key, 'errors.required');
    });
  });

  group('bloodPressureCrossFieldError', () {
    test('systolic greater than diastolic is valid', () {
      expect(bloodPressureCrossFieldError(120, 80), isNull);
    });

    test('systolic equal to diastolic is an error', () {
      expect(
        bloodPressureCrossFieldError(80, 80)?.key,
        'vitals.error.systolicMustExceedDiastolic',
      );
    });

    test('systolic less than diastolic is an error', () {
      expect(
        bloodPressureCrossFieldError(70, 90)?.key,
        'vitals.error.systolicMustExceedDiastolic',
      );
    });
  });
}
