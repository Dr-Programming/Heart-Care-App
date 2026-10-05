import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/app/visit_summary/visit_summary.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

VitalReading _vital(VitalType type, Map<String, double> values, int day) =>
    VitalReading(
      clientRecordId: '$type$day$values',
      serverId: null,
      type: type,
      values: values,
      flagged: null,
      bmi: null,
      measuredAt: DateTime(2026, 9, day, 8),
      note: null,
    );

SymptomCheckIn _checkIn(
  int day, {
  bool chestPain = false,
  String breath = 'NONE',
  bool swelling = false,
  int energy = 7,
  int? heartRate,
  Severity overall = Severity.none,
}) => SymptomCheckIn(
  clientRecordId: 'c$day',
  data: <String, dynamic>{
    'chestPain': <String, dynamic>{'present': chestPain},
    'shortnessOfBreath': breath,
    'swelling': swelling,
    'energyLevel': energy,
    'heartRate': ?heartRate,
    if (heartRate != null)
      'bloodPressure': <String, dynamic>{'systolic': 118, 'diastolic': 76},
  },
  overall: overall,
  perSymptom: const <String, Severity>{},
  measuredAt: DateTime(2026, 9, day, 9),
);

const Adherence _good = Adherence(
  taken: 26,
  due: 28,
  skipped: 0,
  windowDays: 7,
);

void main() {
  test('averages vitals and reports weight change across the window', () {
    final VisitSummary summary = VisitSummary.from(
      windowDays: 7,
      vitals: <VitalReading>[
        _vital(VitalType.bloodPressure, <String, double>{
          'systolic': 130,
          'diastolic': 84,
        }, 24),
        _vital(VitalType.bloodPressure, <String, double>{
          'systolic': 134,
          'diastolic': 84,
        }, 30),
        _vital(VitalType.heartRate, <String, double>{'heartRate': 76}, 29),
        _vital(VitalType.glucose, <String, double>{'glucose': 5.4}, 29),
        _vital(VitalType.weight, <String, double>{'weight': 69}, 24),
        _vital(VitalType.weight, <String, double>{'weight': 68.5}, 30),
      ],
      adherence: _good,
      checkIns: const <SymptomCheckIn>[],
    );

    expect(summary.bpSystolic, 132);
    expect(summary.bpDiastolic, 84);
    expect(summary.heartRate, 76);
    expect(summary.glucose, 5.4);
    expect(summary.weight, 68.5);
    expect(summary.weightChange, -0.5);
    expect(summary.attention, contains(AttentionReason.bpAboveTarget));
    expect(summary.status, VisitStatus.needsAttention);
  });

  test('counts symptom days and average energy', () {
    final VisitSummary summary = VisitSummary.from(
      windowDays: 7,
      vitals: const <VitalReading>[],
      adherence: _good,
      checkIns: <SymptomCheckIn>[
        _checkIn(28, breath: 'MILD', energy: 6),
        _checkIn(29, breath: 'MILD', energy: 7),
        _checkIn(30, energy: 8),
      ],
    );

    expect(summary.checkInCount, 3);
    expect(summary.chestPainDays, 0);
    expect(summary.breathlessMildDays, 2);
    expect(summary.breathlessSevereDays, 0);
    expect(summary.swellingDays, 0);
    expect(summary.averageEnergy, 7);
  });

  test('a week with nothing worrying is stable', () {
    final VisitSummary summary = VisitSummary.from(
      windowDays: 7,
      vitals: <VitalReading>[
        _vital(VitalType.bloodPressure, <String, double>{
          'systolic': 118,
          'diastolic': 76,
        }, 30),
      ],
      adherence: _good,
      checkIns: <SymptomCheckIn>[_checkIn(30)],
    );

    expect(summary.attention, isEmpty);
    expect(summary.status, VisitStatus.stable);
  });

  test(
    'adherence below 80%, chest pain and urgent check-ins need attention',
    () {
      final VisitSummary summary = VisitSummary.from(
        windowDays: 7,
        vitals: const <VitalReading>[],
        adherence: const Adherence(
          taken: 20,
          due: 28,
          skipped: 0,
          windowDays: 7,
        ),
        checkIns: <SymptomCheckIn>[
          _checkIn(30, chestPain: true, overall: Severity.urgent),
        ],
      );

      expect(summary.adherencePercent, 71);
      expect(
        summary.attention,
        containsAll(<AttentionReason>[
          AttentionReason.lowAdherence,
          AttentionReason.chestPain,
          AttentionReason.urgentSymptoms,
        ]),
      );
    },
  );

  test(
    'adherence change is in percentage points against the period before',
    () {
      final VisitSummary summary = VisitSummary.from(
        windowDays: 7,
        vitals: const <VitalReading>[],
        adherence: _good,
        previousAdherence: const Adherence(
          taken: 24,
          due: 28,
          skipped: 0,
          windowDays: 7,
        ),
        checkIns: const <SymptomCheckIn>[],
      );

      expect(summary.adherencePercent, 93);
      expect(summary.adherenceChange, 7);
    },
  );

  test('nothing recorded at all says so instead of "stable"', () {
    final VisitSummary summary = VisitSummary.from(
      windowDays: 7,
      vitals: const <VitalReading>[],
      adherence: const Adherence(taken: 0, due: 0, skipped: 0, windowDays: 7),
      checkIns: const <SymptomCheckIn>[],
    );

    expect(summary.status, VisitStatus.noData);
  });

  test(
    'with nothing logged under Vitals, check-in heart rate and BP are used',
    () {
      final VisitSummary summary = VisitSummary.from(
        windowDays: 7,
        vitals: const <VitalReading>[],
        adherence: _good,
        checkIns: <SymptomCheckIn>[_checkIn(30, heartRate: 76)],
      );

      expect(summary.heartRate, 76);
      expect(summary.bpSystolic, 118);
      expect(summary.bpDiastolic, 76);
    },
  );

  test(
    'BP logged under Vitals is used on its own, matching the BP trend graph',
    () {
      final VisitSummary summary = VisitSummary.from(
        windowDays: 7,
        vitals: <VitalReading>[
          _vital(VitalType.bloodPressure, <String, double>{
            'systolic': 150,
            'diastolic': 95,
          }, 29),
        ],
        adherence: _good,
        checkIns: <SymptomCheckIn>[_checkIn(30, heartRate: 76)],
      );

      expect(summary.bpSystolic, 150);
      expect(summary.bpDiastolic, 95);
      // No heart rate under Vitals, so the check-in's is still shown.
      expect(summary.heartRate, 76);
    },
  );
}
