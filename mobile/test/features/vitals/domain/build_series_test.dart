import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/usecases/build_series.dart';

VitalReading _bp(
  DateTime measuredAt, {
  double systolic = 120,
  double diastolic = 80,
}) {
  return VitalReading(
    clientRecordId: 'id-${measuredAt.microsecondsSinceEpoch}',
    type: VitalType.bloodPressure,
    values: <String, double>{'systolic': systolic, 'diastolic': diastolic},
    flagged: false,
    measuredAt: measuredAt,
  );
}

void main() {
  final DateTime now = DateTime(2026, 8, 30, 12);
  const BuildSeries buildSeries = BuildSeries();

  test('a 7-day window includes a reading from exactly 7 days ago', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now.subtract(const Duration(days: 7)))],
      windowDays: 7,
      now: now,
    );
    expect(series.first.points, hasLength(1));
  });

  test('a 7-day window excludes a reading from 8 days ago', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now.subtract(const Duration(days: 8)))],
      windowDays: 7,
      now: now,
    );
    expect(series, isEmpty);
  });

  test('blood pressure produces two series from one set of readings', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now, systolic: 130, diastolic: 85)],
      windowDays: 7,
      now: now,
    );
    expect(
      series.map((VitalSeries s) => s.key),
      <String>['systolic', 'diastolic'],
    );
    expect(series[0].points.single.value, 130);
    expect(series[1].points.single.value, 85);
  });

  test('an empty window yields no series, not empty ones', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: const <VitalReading>[],
      windowDays: 7,
      now: now,
    );
    expect(series, isEmpty);
  });

  test('points are ordered oldest-to-newest even when input is newest-first', () {
    final DateTime day1 = now.subtract(const Duration(days: 2));
    final DateTime day2 = now.subtract(const Duration(days: 1));
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[
        _bp(day2, systolic: 140), // newest first, as history streams it
        _bp(day1, systolic: 120),
      ],
      windowDays: 7,
      now: now,
    );
    final VitalSeries systolic = series.firstWhere(
      (VitalSeries s) => s.key == 'systolic',
    );
    expect(
      systolic.points.map((VitalPoint p) => p.value),
      <double>[120, 140],
    );
  });

  test('a target value comes through per key when supplied', () {
    final List<VitalSeries> withTarget = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now)],
      windowDays: 7,
      targets: <String, double>{'systolic': 120},
      now: now,
    );
    expect(withTarget.first.targetValue, 120);
    expect(withTarget.last.targetValue, isNull);
  });

  group('VitalSeries summary', () {
    test('min, max and avg are computed over the series', () {
      final VitalSeries s = VitalSeries(
        key: 'systolic',
        points: <VitalPoint>[
          VitalPoint(now, 110),
          VitalPoint(now, 130),
          VitalPoint(now, 120),
        ],
      );
      expect(s.min, 110);
      expect(s.max, 130);
      expect(s.avg, 120);
    });
  });
}
