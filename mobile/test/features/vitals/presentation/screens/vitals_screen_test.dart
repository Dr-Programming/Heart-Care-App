import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows an empty state when nothing has been logged', (
    WidgetTester tester,
  ) async {
    final List<Override> overrides = <Override>[
      watchHistoryProvider.overrideWithValue(
        WatchHistory(_FakeEmptyRepository()),
      ),
    ];
    await pumpApp(tester, const VitalsScreen(), overrides: overrides);
    await tester.pump();

    expect(find.text('vitals.emptyTitle'.tr()), findsOneWidget);
  });

  testWidgets('shows a tile per type once readings exist', (
    WidgetTester tester,
  ) async {
    final VitalReading glucose = VitalReading(
      clientRecordId: 'g1',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.5},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
    final List<Override> overrides = <Override>[
      watchHistoryProvider.overrideWithValue(
        WatchHistory(_FakeRepository(<VitalReading>[glucose])),
      ),
    ];
    await pumpApp(tester, const VitalsScreen(), overrides: overrides);
    await tester.pump();

    expect(find.text('vitals.type.glucose'.tr()), findsOneWidget);
  });
}

class _FakeEmptyRepository implements VitalsRepository {
  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(const <VitalReading>[]);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readings);
  final List<VitalReading> readings;

  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(readings);

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    final Iterable<VitalReading> matches = readings.where(
      (VitalReading r) => r.type == type,
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}
