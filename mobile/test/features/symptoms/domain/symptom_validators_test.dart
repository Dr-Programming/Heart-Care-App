import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/validators/symptom_validators.dart';

SymptomCheckIn _checkIn({
  ChestPain chestPain = ChestPain.none,
  ShortnessOfBreath shortnessOfBreath = ShortnessOfBreath.none,
  int heartRate = 72,
  BloodPressureReading bloodPressure = const BloodPressureReading(
    systolic: 120,
    diastolic: 80,
  ),
  bool swelling = false,
  int energyLevel = 7,
}) {
  return SymptomCheckIn(
    clientRecordId: 'id',
    chestPain: chestPain,
    shortnessOfBreath: shortnessOfBreath,
    heartRate: heartRate,
    bloodPressure: bloodPressure,
    swelling: swelling,
    energyLevel: energyLevel,
    measuredAt: DateTime.utc(2026, 9, 2),
  );
}

void main() {
  test('a fully "fine today" check-in has no errors', () {
    expect(validateSymptomCheckIn(_checkIn()), isEmpty);
  });

  group('chest pain severity', () {
    test('is required when chest pain is present', () {
      final Set<SymptomValidationError> errors = validateSymptomCheckIn(
        _checkIn(chestPain: const ChestPain(present: true)),
      );
      expect(
        errors,
        contains(SymptomValidationError.chestPainSeverityRequired),
      );
    });

    test('is ignored when chest pain is not present, even if set anyway', () {
      final Set<SymptomValidationError> errors = validateSymptomCheckIn(
        _checkIn(chestPain: const ChestPain(present: false, severity: 9)),
      );
      expect(errors, isEmpty);
    });

    test('must be within 0-10 when present', () {
      expect(
        validateSymptomCheckIn(
          _checkIn(chestPain: const ChestPain(present: true, severity: 11)),
        ),
        contains(SymptomValidationError.chestPainSeverityOutOfRange),
      );
      expect(
        validateSymptomCheckIn(
          _checkIn(chestPain: const ChestPain(present: true, severity: -1)),
        ),
        contains(SymptomValidationError.chestPainSeverityOutOfRange),
      );
    });

    test('accepts the bounds themselves', () {
      expect(
        validateSymptomCheckIn(
          _checkIn(chestPain: const ChestPain(present: true, severity: 0)),
        ),
        isEmpty,
      );
      expect(
        validateSymptomCheckIn(
          _checkIn(chestPain: const ChestPain(present: true, severity: 10)),
        ),
        isEmpty,
      );
    });
  });

  group('heart rate is 20-300', () {
    test('accepts the bounds', () {
      expect(validateSymptomCheckIn(_checkIn(heartRate: 20)), isEmpty);
      expect(validateSymptomCheckIn(_checkIn(heartRate: 300)), isEmpty);
    });

    test('rejects outside the bounds', () {
      expect(
        validateSymptomCheckIn(_checkIn(heartRate: 19)),
        contains(SymptomValidationError.heartRateOutOfRange),
      );
      expect(
        validateSymptomCheckIn(_checkIn(heartRate: 301)),
        contains(SymptomValidationError.heartRateOutOfRange),
      );
    });
  });

  group('blood pressure is 40-300 with systolic > diastolic', () {
    test('accepts a normal reading', () {
      expect(
        validateSymptomCheckIn(
          _checkIn(
            bloodPressure: const BloodPressureReading(
              systolic: 120,
              diastolic: 80,
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('rejects a value outside 40-300 on either side', () {
      expect(
        validateSymptomCheckIn(
          _checkIn(
            bloodPressure: const BloodPressureReading(
              systolic: 39,
              diastolic: 80,
            ),
          ),
        ),
        contains(SymptomValidationError.bloodPressureOutOfRange),
      );
      expect(
        validateSymptomCheckIn(
          _checkIn(
            bloodPressure: const BloodPressureReading(
              systolic: 120,
              diastolic: 301,
            ),
          ),
        ),
        contains(SymptomValidationError.bloodPressureOutOfRange),
      );
    });

    test('rejects systolic <= diastolic even when both are in range', () {
      expect(
        validateSymptomCheckIn(
          _checkIn(
            bloodPressure: const BloodPressureReading(
              systolic: 80,
              diastolic: 80,
            ),
          ),
        ),
        contains(SymptomValidationError.bloodPressureNotGreaterThanDiastolic),
      );
      expect(
        validateSymptomCheckIn(
          _checkIn(
            bloodPressure: const BloodPressureReading(
              systolic: 70,
              diastolic: 90,
            ),
          ),
        ),
        contains(SymptomValidationError.bloodPressureNotGreaterThanDiastolic),
      );
    });
  });

  group('energy level is 0-10', () {
    test('accepts the bounds', () {
      expect(validateSymptomCheckIn(_checkIn(energyLevel: 0)), isEmpty);
      expect(validateSymptomCheckIn(_checkIn(energyLevel: 10)), isEmpty);
    });

    test('rejects outside the bounds', () {
      expect(
        validateSymptomCheckIn(_checkIn(energyLevel: -1)),
        contains(SymptomValidationError.energyLevelOutOfRange),
      );
      expect(
        validateSymptomCheckIn(_checkIn(energyLevel: 11)),
        contains(SymptomValidationError.energyLevelOutOfRange),
      );
    });
  });

  group('ShortnessOfBreath round-trips through its wire form', () {
    test('every value maps to and from its wire spelling', () {
      expect(ShortnessOfBreath.values, hasLength(3));
      for (final ShortnessOfBreath s in ShortnessOfBreath.values) {
        expect(ShortnessOfBreath.fromWire(s.wire), s);
      }
    });

    test('the wire spellings match the API contract exactly', () {
      expect(ShortnessOfBreath.none.wire, 'NONE');
      expect(ShortnessOfBreath.mild.wire, 'MILD');
      expect(ShortnessOfBreath.severe.wire, 'SEVERE');
    });
  });

  group('SymptomKey round-trips through its wire form', () {
    test('all six keys map to and from their wire spelling', () {
      expect(SymptomKey.values, hasLength(6));
      for (final SymptomKey k in SymptomKey.values) {
        expect(SymptomKey.fromWire(k.wire), k);
      }
    });

    test('the wire spellings match the JSON key spellings exactly', () {
      expect(SymptomKey.chestPain.wire, 'chestPain');
      expect(SymptomKey.shortnessOfBreath.wire, 'shortnessOfBreath');
      expect(SymptomKey.heartRate.wire, 'heartRate');
      expect(SymptomKey.bloodPressure.wire, 'bloodPressure');
      expect(SymptomKey.swelling.wire, 'swelling');
      expect(SymptomKey.energyLevel.wire, 'energyLevel');
    });
  });
}
