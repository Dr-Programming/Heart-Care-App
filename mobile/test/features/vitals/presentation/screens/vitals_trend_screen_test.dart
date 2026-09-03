import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_trend_screen.dart';
import 'package:libu_care/features/vitals/presentation/widgets/trend_chart.dart';
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
    return Stream<List<VitalReading>>.value(
      type == null
          ? readings
          : readings.where((VitalReading r) => r.type == type).toList(),
    );
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

VitalReading _glucose(DateTime d, double v, String id) => VitalReading(
  clientRecordId: id,
  type: VitalType.glucose,
  values: <String, double>{'glucose': v},
  flagged: false,
  measuredAt: d,
);

void main() {
  setUpWidgetTests();

  testWidgets('a trend with two points shows the insufficient-data state', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _glucose(now.subtract(const Duration(days: 1)), 5.5, 'a'),
      _glucose(now.subtract(const Duration(days: 2)), 6.0, 'b'),
    ]);
    await pumpApp(
      tester,
      const VitalsTrendScreen(type: VitalType.glucose),
      overrides: <Override>[vitalsRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pump();

    expect(
      find.text(
        'vitals.trendInsufficientData'.tr(
          namedArgs: <String, String>{'count': '3'},
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a trend with three or more points renders the chart', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _glucose(now.subtract(const Duration(days: 1)), 5.5, 'a'),
      _glucose(now.subtract(const Duration(days: 2)), 6.0, 'b'),
      _glucose(now.subtract(const Duration(days: 3)), 5.0, 'c'),
    ]);
    await pumpApp(
      tester,
      const VitalsTrendScreen(type: VitalType.glucose),
      overrides: <Override>[vitalsRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pump();

    expect(find.byType(TrendChart), findsOneWidget);
  });
}
