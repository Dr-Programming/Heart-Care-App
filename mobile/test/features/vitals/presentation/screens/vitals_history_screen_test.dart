import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_history_screen.dart';
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
  }) {
    final List<VitalReading> filtered = type == null
        ? readings
        : readings.where((VitalReading r) => r.type == type).toList();
    return Stream<List<VitalReading>>.value(filtered);
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  VitalReading reading(VitalType type, Map<String, double> values, String id) {
    return VitalReading(
      clientRecordId: id,
      type: type,
      values: values,
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
  }

  testWidgets('lists every reading with no filter applied', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      reading(VitalType.glucose, <String, double>{'glucose': 5.5}, 'g1'),
      reading(VitalType.weight, <String, double>{'weight': 70}, 'w1'),
    ]);
    await pumpApp(
      tester,
      const VitalsHistoryScreen(),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(WatchHistory(repo)),
      ],
    );
    await tester.pump();

    expect(find.textContaining('5.5'), findsOneWidget);
    expect(find.textContaining('70.0'), findsOneWidget);
  });

  testWidgets('the type filter narrows the list to one type', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      reading(VitalType.glucose, <String, double>{'glucose': 5.5}, 'g1'),
      reading(VitalType.weight, <String, double>{'weight': 70}, 'w1'),
    ]);
    await pumpApp(
      tester,
      const VitalsHistoryScreen(),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(WatchHistory(repo)),
      ],
    );
    await tester.pump();

    await tester.tap(find.text('vitals.type.glucose'.tr()));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('5.5'), findsOneWidget);
    expect(find.textContaining('70.0'), findsNothing);
  });
}
