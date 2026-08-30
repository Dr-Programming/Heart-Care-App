import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';

/// These cases are copied from the backend's own rules
/// (`SymptomAssessment.java`, `VitalThresholds.java`). If one of them starts
/// failing, the client and the server disagree about how severe a reading is —
/// which shows up to the user as a status that changes after a sync.
void main() {
  group('blood pressure severity mirrors the backend', () {
    test('systolic at or above 180 is an emergency', () {
      expect(bloodPressureSeverity(180, 80), Severity.emergency);
      expect(bloodPressureSeverity(200, 95), Severity.emergency);
    });

    test('the urgent band is 160+, 90-, 100+ diastolic or 60- diastolic', () {
      expect(bloodPressureSeverity(160, 80), Severity.urgent);
      expect(bloodPressureSeverity(90, 70), Severity.urgent);
      expect(bloodPressureSeverity(130, 100), Severity.urgent);
      expect(bloodPressureSeverity(130, 60), Severity.urgent);
    });

    test('a normal reading scores none', () {
      expect(bloodPressureSeverity(120, 80), Severity.none);
    });

    test('the boundaries are inclusive on both sides', () {
      expect(bloodPressureSeverity(159, 99), Severity.none);
      expect(bloodPressureSeverity(91, 61), Severity.none);
    });
  });

  group('heart rate severity mirrors the backend', () {
    test('below 40 or above 120 is urgent', () {
      expect(heartRateSeverity(39), Severity.urgent);
      expect(heartRateSeverity(121), Severity.urgent);
    });

    test('the bounds themselves are not urgent', () {
      expect(heartRateSeverity(40), Severity.none);
      expect(heartRateSeverity(120), Severity.none);
      expect(heartRateSeverity(72), Severity.none);
    });
  });

  group('glucose severity', () {
    test('FR-DEC-007 bounds are urgent', () {
      expect(glucoseSeverity(3.8), Severity.urgent);
      expect(glucoseSeverity(15.1), Severity.urgent);
    });

    test('the server flag band is a watch, not an emergency', () {
      expect(glucoseSeverity(3.95), Severity.monitor);
      expect(glucoseSeverity(12.0), Severity.monitor);
    });

    test('an in-range reading scores none', () {
      expect(glucoseSeverity(5.5), Severity.none);
    });
  });

  group('isVitalFlagged mirrors VitalThresholds', () {
    test('flags a value at or beyond a bound', () {
      expect(isVitalFlagged(<String, num?>{'systolic': 180}), isTrue);
      expect(isVitalFlagged(<String, num?>{'systolic': 90}), isTrue);
      expect(isVitalFlagged(<String, num?>{'ldl': 4.9}), isTrue);
      expect(isVitalFlagged(<String, num?>{'hdl': 1.0}), isTrue);
    });

    test('does not flag an in-range reading', () {
      expect(
        isVitalFlagged(<String, num?>{'systolic': 120, 'diastolic': 80}),
        isFalse,
      );
    });

    test('a one-sided range only breaches on its defined side', () {
      // ldl has no low bound, so a very low LDL is not a flag.
      expect(isVitalFlagged(<String, num?>{'ldl': 0.5}), isFalse);
      // hdl has no high bound.
      expect(isVitalFlagged(<String, num?>{'hdl': 9.0}), isFalse);
    });

    test('ignores keys it does not know and nulls', () {
      expect(isVitalFlagged(<String, num?>{'unknown': 9999}), isFalse);
      expect(isVitalFlagged(<String, num?>{'systolic': null}), isFalse);
    });
  });

  group('severityForVital', () {
    test('weight is judged on BMI, not the raw weight', () {
      expect(
        severityForVital(type: 'WEIGHT', values: <String, num?>{'weight': 300}),
        Severity.none,
        reason: 'no BMI supplied, so nothing can be judged',
      );
      expect(
        severityForVital(
          type: 'WEIGHT',
          values: <String, num?>{'weight': 95},
          bmi: 31,
        ),
        Severity.monitor,
      );
    });

    test('an incomplete blood pressure reading scores none', () {
      expect(
        severityForVital(
          type: 'BLOOD_PRESSURE',
          values: <String, num?>{'systolic': 190},
        ),
        Severity.none,
      );
    });

    test('cholesterol out of range is a watch', () {
      expect(
        severityForVital(
          type: 'CHOLESTEROL',
          values: <String, num?>{'ldl': 5.2, 'hdl': 1.4, 'total': 6.0},
        ),
        Severity.monitor,
      );
    });
  });

  group('assessSymptoms mirrors SymptomAssessment.java', () {
    Map<String, dynamic> checkIn({
      bool chestPain = false,
      int chestPainSeverity = 0,
      String breath = 'NONE',
      int systolic = 120,
      int diastolic = 80,
      int heartRate = 72,
      bool swelling = false,
      int energy = 7,
    }) {
      return <String, dynamic>{
        'chestPain': <String, dynamic>{
          'present': chestPain,
          'severity': chestPainSeverity,
        },
        'shortnessOfBreath': breath,
        'bloodPressure': <String, dynamic>{
          'systolic': systolic,
          'diastolic': diastolic,
        },
        'heartRate': heartRate,
        'swelling': swelling,
        'energyLevel': energy,
      };
    }

    test('a clean check-in is none', () {
      expect(assessSymptoms(checkIn()).overall, Severity.none);
    });

    test('chest pain bands are 1-3 monitor, 4-6 urgent, 7+ emergency', () {
      expect(
        assessSymptoms(checkIn(chestPain: true, chestPainSeverity: 2)).overall,
        Severity.monitor,
      );
      expect(
        assessSymptoms(checkIn(chestPain: true, chestPainSeverity: 4)).overall,
        Severity.urgent,
      );
      expect(
        assessSymptoms(checkIn(chestPain: true, chestPainSeverity: 7)).overall,
        Severity.emergency,
      );
    });

    test('severity is ignored when chest pain is not present', () {
      expect(
        assessSymptoms(checkIn(chestPainSeverity: 9)).overall,
        Severity.none,
      );
    });

    test('shortness of breath maps SEVERE to urgent and MILD to monitor', () {
      expect(
        assessSymptoms(checkIn(breath: 'SEVERE')).overall,
        Severity.urgent,
      );
      expect(assessSymptoms(checkIn(breath: 'MILD')).overall, Severity.monitor);
    });

    test('energy of 2 or less is a watch', () {
      expect(assessSymptoms(checkIn(energy: 2)).overall, Severity.monitor);
      expect(assessSymptoms(checkIn(energy: 3)).overall, Severity.none);
    });

    test('overall is the worst single symptom, not an average', () {
      final SymptomAssessment result = assessSymptoms(
        checkIn(chestPain: true, chestPainSeverity: 8, energy: 10),
      );
      expect(result.overall, Severity.emergency);
      expect(result.symptoms['energyLevel'], Severity.none);
      expect(result.symptoms['chestPain'], Severity.emergency);
    });

    test('a half-filled draft scores rather than throwing', () {
      expect(assessSymptoms(<String, dynamic>{}).overall, Severity.none);
      expect(
        assessSymptoms(<String, dynamic>{'chestPain': 'nonsense'}).overall,
        Severity.none,
      );
    });
  });

  group('adherence', () {
    test('two consecutive misses trigger an alert', () {
      expect(
        hasConsecutiveMissedDoses(<String>['MISSED', 'MISSED', 'TAKEN']),
        isTrue,
      );
    });

    test('a single miss does not', () {
      expect(
        hasConsecutiveMissedDoses(<String>['MISSED', 'TAKEN', 'MISSED']),
        isFalse,
      );
    });

    test('the run must be the most recent doses', () {
      expect(
        hasConsecutiveMissedDoses(<String>['TAKEN', 'MISSED', 'MISSED']),
        isFalse,
      );
    });

    test('a skipped dose is a decision, not a miss', () {
      expect(
        hasConsecutiveMissedDoses(<String>['SKIPPED', 'MISSED', 'MISSED']),
        isFalse,
      );
    });

    test('an empty history is not an alert', () {
      expect(hasConsecutiveMissedDoses(<String>[]), isFalse);
    });
  });

  group('adherence cross-signal (FR-DEC-003)', () {
    test('missed doses plus chest pain is urgent', () {
      expect(
        adherenceCrossSignal(
          missedDoseToday: true,
          chestPainToday: true,
          severeBreathlessnessToday: false,
        ),
        Severity.urgent,
      );
    });

    test('missed doses alone is only a watch', () {
      expect(
        adherenceCrossSignal(
          missedDoseToday: true,
          chestPainToday: false,
          severeBreathlessnessToday: false,
        ),
        Severity.monitor,
      );
    });

    test('symptoms without a missed dose are handled elsewhere', () {
      expect(
        adherenceCrossSignal(
          missedDoseToday: false,
          chestPainToday: true,
          severeBreathlessnessToday: true,
        ),
        Severity.none,
      );
    });
  });

  group('Severity', () {
    test('is ordered least to most severe', () {
      expect(Severity.emergency > Severity.urgent, isTrue);
      expect(Severity.urgent > Severity.monitor, isTrue);
      expect(Severity.monitor > Severity.none, isTrue);
    });

    test('round-trips the wire form the server sends', () {
      expect(Severity.fromWire('EMERGENCY'), Severity.emergency);
      expect(Severity.fromWire('MONITOR'), Severity.monitor);
    });

    test('falls back to none for an unknown value', () {
      expect(Severity.fromWire('SOMETHING_NEW'), Severity.none);
      expect(Severity.fromWire(null), Severity.none);
    });

    test('every severity has a recommended action key (FR-DEC-009)', () {
      for (final Severity severity in Severity.values) {
        expect(actionKeyFor(severity), startsWith('clinical.action.'));
      }
    });
  });
}
