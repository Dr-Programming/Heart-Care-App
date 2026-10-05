import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/bp_trend.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

VitalReading _bp(DateTime at, double sys, double dia) => VitalReading(
  clientRecordId: '$at',
  serverId: null,
  type: VitalType.bloodPressure,
  values: <String, double>{'systolic': sys, 'diastolic': dia},
  flagged: null,
  bmi: null,
  measuredAt: at,
  note: null,
);

void main() {
  final DateTime now = DateTime(2026, 9, 30, 20);

  test('averages the window and compares with the previous one', () {
    final BpTrend trend = BpTrend.of(
      readings: <VitalReading>[
        _bp(DateTime(2026, 9, 29, 8), 130, 84),
        _bp(DateTime(2026, 9, 30, 8), 134, 84),
      ],
      previous: <VitalReading>[_bp(DateTime(2026, 9, 20, 8), 128, 80)],
      windowDays: 7,
      now: now,
    );

    expect(trend.averageSystolic, 132);
    expect(trend.averageDiastolic, 84);
    expect(trend.systolicChange, 4);
  });

  test(
    'without a goal the target is 120/80; above it on either number counts',
    () {
      final BpTrend trend = BpTrend.of(
        readings: <VitalReading>[
          _bp(DateTime(2026, 9, 28, 8), 118, 76),
          _bp(DateTime(2026, 9, 29, 8), 118, 86),
          _bp(DateTime(2026, 9, 30, 8), 140, 78),
        ],
        previous: const <VitalReading>[],
        windowDays: 7,
        now: now,
      );

      expect(trend.targetSystolic, 120);
      expect(trend.targetDiastolic, 80);
      expect(trend.daysWithReadings, 3);
      expect(trend.daysAboveTarget, 2);
      expect(trend.systolicChange, isNull);
      expect(trend.status, BpTrendStatus.aboveTarget);
    },
  );

  test('a goal set in the profile replaces the default target', () {
    final BpTrend trend = BpTrend.of(
      readings: <VitalReading>[_bp(DateTime(2026, 9, 30, 8), 128, 78)],
      previous: const <VitalReading>[],
      windowDays: 7,
      goals: const VitalGoals(bpSystolic: 130, bpDiastolic: 80),
      now: now,
    );

    expect(trend.targetSystolic, 130);
    expect(trend.status, BpTrendStatus.onTarget);
  });

  test('a day at or above 180/120 is critical', () {
    final BpTrend trend = BpTrend.of(
      readings: <VitalReading>[_bp(DateTime(2026, 9, 30, 8), 182, 100)],
      previous: const <VitalReading>[],
      windowDays: 7,
      now: now,
    );

    expect(trend.status, BpTrendStatus.critical);
  });

  test('one point per day, averaged, oldest first', () {
    final BpTrend trend = BpTrend.of(
      readings: <VitalReading>[
        _bp(DateTime(2026, 9, 30, 20), 140, 90),
        _bp(DateTime(2026, 9, 30, 8), 120, 80),
        _bp(DateTime(2026, 9, 28, 8), 126, 82),
      ],
      previous: const <VitalReading>[],
      windowDays: 7,
      now: now,
    );

    expect(trend.days.map((BpDay d) => d.day), <DateTime>[
      DateTime(2026, 9, 28),
      DateTime(2026, 9, 30),
    ]);
    expect(trend.days.last.systolic, 130);
    expect(trend.days.last.diastolic, 85);
  });

  test('no readings in the window means no trend', () {
    final BpTrend trend = BpTrend.of(
      readings: const <VitalReading>[],
      previous: const <VitalReading>[],
      windowDays: 7,
      now: now,
    );

    expect(trend.hasData, isFalse);
    expect(trend.status, BpTrendStatus.noData);
  });
}
