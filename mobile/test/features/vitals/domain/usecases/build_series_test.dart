import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/utils/date_formatter.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/build_series.dart';

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readingsToReturn, {this.goals});

  final List<VitalReading> readingsToReturn;
  final VitalGoals? goals;
  DateTime? capturedFrom;
  DateTime? capturedTo;

  @override
  Future<List<VitalReading>> history({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) async {
    capturedFrom = from;
    capturedTo = to;
    return readingsToReturn;
  }

  @override
  Future<VitalReading> logReading({
    required VitalType type,
    required Map<String, double> values,
    DateTime? measuredAt,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<Map<VitalType, VitalReading?>> latestByType() =>
      throw UnimplementedError();

  @override
  Future<double?> latestHeightCm() => throw UnimplementedError();

  @override
  Future<VitalGoals?> latestGoals() async => goals;
}

VitalReading _reading(DateTime measuredAt, Map<String, double> values) {
  return VitalReading(
    clientRecordId: 'c-${measuredAt.millisecondsSinceEpoch}',
    serverId: null,
    type: VitalType.bloodPressure,
    values: values,
    flagged: false,
    bmi: null,
    measuredAt: measuredAt,
    note: null,
  );
}

void main() {
  final DateTime now = DateTime.utc(2026, 9, 5, 12);

  test('fewer than 3 readings is insufficient data', () async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _reading(now, <String, double>{'systolic': 120, 'diastolic': 80}),
      _reading(now, <String, double>{'systolic': 122, 'diastolic': 81}),
    ]);
    final BuildSeries useCase = BuildSeries(repo);

    final VitalSeriesResult result = await useCase(
      type: VitalType.bloodPressure,
      windowDays: 7,
      now: now,
    );

    expect(result, isA<VitalInsufficientData>());
  });

  test('an empty window is insufficient data, not an empty chart', () async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[]);
    final BuildSeries useCase = BuildSeries(repo);

    final VitalSeriesResult result = await useCase(
      type: VitalType.glucose,
      windowDays: 7,
      now: now,
    );

    expect(result, isA<VitalInsufficientData>());
  });

  test('BP produces two series from one set of readings', () async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _reading(now, <String, double>{'systolic': 120, 'diastolic': 80}),
      _reading(
        now.subtract(const Duration(days: 1)),
        <String, double>{'systolic': 122, 'diastolic': 81},
      ),
      _reading(
        now.subtract(const Duration(days: 2)),
        <String, double>{'systolic': 118, 'diastolic': 79},
      ),
    ]);
    final BuildSeries useCase = BuildSeries(repo);

    final VitalSeriesResult result = await useCase(
      type: VitalType.bloodPressure,
      windowDays: 7,
      now: now,
    );

    expect(result, isA<VitalTrendData>());
    final VitalTrendData data = result as VitalTrendData;
    expect(data.series.length, 2);
    expect(data.series[0].label, 'vitals.field.systolic');
    expect(data.series[1].label, 'vitals.field.diastolic');
  });

  test('readings are ordered oldest-to-newest for plotting', () async {
    final DateTime day0 = now.subtract(const Duration(days: 2));
    final DateTime day1 = now.subtract(const Duration(days: 1));
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _reading(now, <String, double>{'systolic': 120, 'diastolic': 80}),
      _reading(day1, <String, double>{'systolic': 122, 'diastolic': 81}),
      _reading(day0, <String, double>{'systolic': 118, 'diastolic': 79}),
    ]);
    final BuildSeries useCase = BuildSeries(repo);

    final VitalSeriesResult result = await useCase(
      type: VitalType.bloodPressure,
      windowDays: 7,
      now: now,
    );

    final VitalTrendData data = result as VitalTrendData;
    expect(data.readings.first.measuredAt, day0);
    expect(data.readings.last.measuredAt, now);
  });

  test('a 7-day window includes today and excludes day 8', () async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[]);
    final BuildSeries useCase = BuildSeries(repo);

    await useCase(type: VitalType.glucose, windowDays: 7, now: now);

    final DateTime expectedFrom = DateFormatter.daysAgo(6, from: now);
    expect(repo.capturedFrom, expectedFrom);
    expect(repo.capturedTo, now);
  });
}
