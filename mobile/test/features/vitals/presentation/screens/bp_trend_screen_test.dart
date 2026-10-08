import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/presentation/screens/bp_trend_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

class _Repo implements VitalsRepository {
  _Repo(this.readings);

  final List<VitalReading> readings;

  @override
  Future<List<VitalReading>> history({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) async => readings
      .where(
        (VitalReading r) =>
            (from == null || !r.measuredAt.isBefore(from)) &&
            (to == null || !r.measuredAt.isAfter(to)),
      )
      .toList();

  @override
  Future<VitalGoals?> latestGoals() async => null;

  @override
  Future<double?> latestHeightCm() async => null;

  @override
  Future<Map<VitalType, VitalReading?>> latestByType() async =>
      <VitalType, VitalReading?>{};

  @override
  Future<VitalReading> logReading({
    required VitalType type,
    required Map<String, double> values,
    DateTime? measuredAt,
    String? note,
  }) => throw UnimplementedError();
}

VitalReading _bp(int daysAgo, double sys, double dia) {
  final DateTime now = DateTime.now();
  return VitalReading(
    clientRecordId: 'r$daysAgo',
    serverId: null,
    type: VitalType.bloodPressure,
    values: <String, double>{'systolic': sys, 'diastolic': dia},
    flagged: null,
    bmi: null,
    // A minute ago, so 'today' is never in the future whatever the time of day.
    measuredAt: now.subtract(Duration(days: daysAgo, minutes: 1)),
    note: null,
  );
}

void main() {
  setUpWidgetTests();

  for (final AppLanguage language in AppLanguage.values) {
    testWidgets(
      'shows the average, the target and days above it (${language.code})',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);

        await pumpApp(
          tester,
          const BpTrendScreen(),
          language: language,
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            onlineStatusProvider.overrideWith(
              (ref) => Stream<bool>.value(true),
            ),
            vitalsRepositoryProvider.overrideWithValue(
              _Repo(<VitalReading>[
                _bp(0, 136, 86),
                _bp(1, 128, 82),
                _bp(2, 118, 76),
              ]),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('127'), findsOneWidget);
        expect(
          find.text('vitals.bpTrend.status.aboveTarget'.tr()),
          findsOneWidget,
        );
        final Finder daysAbove = find.text(
          'vitals.bpTrend.daysAbove'.tr(
            namedArgs: <String, String>{'above': '2', 'days': '3'},
          ),
        );
        await tester.scrollUntilVisible(daysAbove, 200);
        expect(daysAbove, findsOneWidget);
      },
    );
  }
}
