import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/latest_by_type.dart';
import 'package:libu_care/features/vitals/domain/usecases/log_vital.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';

class _FakeVitalsRepository implements VitalsRepository {
  VitalReading? loggedReading;
  VitalType? watchedType;
  DateTime? watchedFrom;
  DateTime? watchedTo;
  VitalType? latestRequestedType;

  @override
  Future<void> log(VitalReading reading) async {
    loggedReading = reading;
  }

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    watchedType = type;
    watchedFrom = from;
    watchedTo = to;
    return Stream<List<VitalReading>>.value(const <VitalReading>[]);
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    latestRequestedType = type;
    return null;
  }

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

VitalReading _reading() => VitalReading(
  clientRecordId: 'abc',
  type: VitalType.glucose,
  values: <String, double>{'glucose': 6.2},
  flagged: false,
  measuredAt: DateTime(2026, 8, 30),
);

void main() {
  late _FakeVitalsRepository repo;

  setUp(() => repo = _FakeVitalsRepository());

  test('LogVital delegates to repository.log with the exact reading', () async {
    final VitalReading reading = _reading();
    await LogVital(repo)(reading);
    expect(repo.loggedReading, same(reading));
  });

  test('WatchHistory delegates to repository.watchHistory with its filters', () {
    final DateTime from = DateTime(2026, 8, 1);
    final DateTime to = DateTime(2026, 8, 30);
    WatchHistory(repo)(type: VitalType.weight, from: from, to: to);
    expect(repo.watchedType, VitalType.weight);
    expect(repo.watchedFrom, from);
    expect(repo.watchedTo, to);
  });

  test('LatestByType delegates to repository.latestByType', () async {
    await LatestByType(repo)(VitalType.heartRate);
    expect(repo.latestRequestedType, VitalType.heartRate);
  });
}
