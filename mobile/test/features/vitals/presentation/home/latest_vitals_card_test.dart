import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/home/latest_vitals_card.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

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
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  test('is registered at order 200 with a stable id', () {
    expect(latestVitalsCard.id, 'vitals-latest');
    expect(latestVitalsCard.order, 200);
  });

  testWidgets('shows "—" for a type with no readings, never hides the row', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      Builder(builder: latestVitalsCard.builder),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(
          WatchHistory(_FakeRepository(const <VitalReading>[])),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('common.noValue'.tr()), findsNWidgets(3));
  });

  testWidgets('shows the latest blood pressure when one exists', (
    WidgetTester tester,
  ) async {
    final VitalReading bp = VitalReading(
      clientRecordId: 'bp1',
      type: VitalType.bloodPressure,
      values: <String, double>{'systolic': 128, 'diastolic': 82},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
    await pumpApp(
      tester,
      Builder(builder: latestVitalsCard.builder),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(
          WatchHistory(_FakeRepository(<VitalReading>[bp])),
        ),
      ],
    );
    await tester.pump();

    expect(find.textContaining('128/82'), findsOneWidget);
  });
}
