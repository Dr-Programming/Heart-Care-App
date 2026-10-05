import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/presentation/controllers/check_in_hub_controller.dart';
import 'package:libu_care/features/symptoms/presentation/screens/check_in_hub_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

class _FakeHub extends CheckInHubController {
  _FakeHub(this.today);

  final SymptomCheckIn? today;

  @override
  Future<SymptomCheckIn?> build() async => today;
}

void main() {
  setUpWidgetTests();

  Future<void> pump(WidgetTester tester, SymptomCheckIn? today) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const CheckInHubScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        checkInHubControllerProvider.overrideWith(() => _FakeHub(today)),
      ],
    );
    await tester.pumpAndSettle();
  }

  SymptomCheckIn checkIn(
    Severity overall, [
    Map<String, Severity> per = const <String, Severity>{},
  ]) => SymptomCheckIn(
    clientRecordId: 'c1',
    data: const <String, dynamic>{},
    overall: overall,
    perSymptom: per,
    measuredAt: DateTime.now(),
  );

  testWidgets('before the check-in, a tip says to check in before exercising', (
    tester,
  ) async {
    await pump(tester, null);

    expect(find.byKey(const Key('checkInFirstTip')), findsOneWidget);
    expect(find.byKey(const Key('activityGuidanceCard')), findsNothing);
  });

  testWidgets('after an all-normal check-in, activities to do are suggested', (
    tester,
  ) async {
    await pump(tester, checkIn(Severity.none));

    expect(find.byKey(const Key('checkInFirstTip')), findsNothing);
    expect(find.byKey(const Key('activityGuidanceCard')), findsOneWidget);
    expect(find.text('activityGuidance.message.moderate'.tr()), findsOneWidget);
    expect(find.text('activity.type.WALKING'.tr()), findsOneWidget);
    expect(find.text('activityGuidance.avoid'.tr()), findsNothing);
  });

  testWidgets('after a watch-level check-in, it lists what to avoid', (
    tester,
  ) async {
    await pump(tester, checkIn(Severity.monitor));

    expect(find.text('activityGuidance.message.light'.tr()), findsOneWidget);
    expect(find.text('activityGuidance.avoid'.tr()), findsOneWidget);
    expect(find.text('activity.type.JOGGING'.tr()), findsOneWidget);
  });

  testWidgets('has a shortcut to the healthy exercises topic', (tester) async {
    await pump(tester, null);

    await tester.scrollUntilVisible(
      find.byKey(const Key('healthyExercisesLink')),
      100,
    );
    expect(find.text('activityGuidance.learnTitle'.tr()), findsOneWidget);
  });
}
