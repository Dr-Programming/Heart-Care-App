import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/repositories/symptom_repository.dart';
import 'package:libu_care/features/symptoms/presentation/screens/symptom_history_screen.dart';
import 'package:libu_care/features/symptoms/presentation/widgets/check_in_result_view.dart';
import 'package:libu_care/features/symptoms/symptom_providers.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

SymptomCheckIn _checkIn({DateTime? at, String? note, bool worse = false}) =>
    SymptomCheckIn(
      clientRecordId: 'c1',
      data: <String, dynamic>{
        'chestPain': <String, dynamic>{'present': true, 'severity': 2},
        'shortnessOfBreath': 'NONE',
        'heartRate': 78,
        'bloodPressure': <String, dynamic>{'systolic': 124, 'diastolic': 80},
        'swelling': false,
        'energyLevel': 5,
        if (worse)
          'worseThanYesterday': <String, dynamic>{'chestPain': true},
      },
      overall: Severity.monitor,
      perSymptom: const <String, Severity>{
        'chestPain': Severity.monitor,
        'shortnessOfBreath': Severity.none,
        'bloodPressure': Severity.monitor,
        'heartRate': Severity.none,
        'swelling': Severity.none,
        'energyLevel': Severity.none,
      },
      measuredAt: at ?? DateTime.now(),
      note: note,
    );

class _FakeRepo implements SymptomRepository {
  _FakeRepo(this.entries);

  final List<SymptomCheckIn> entries;

  @override
  Future<List<SymptomCheckIn>> history() async => entries;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpWidgetTests();

  Widget host(Widget child) => Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  testWidgets('lists what the patient entered for every question', (
    tester,
  ) async {
    await pumpApp(
      tester,
      host(CheckInResultView(result: _checkIn(note: 'Felt tired'))),
    );

    for (final String field in CheckInResultView.fields) {
      await tester.scrollUntilVisible(
        find.byKey(Key('checkInAnswer_$field')),
        80,
      );
      expect(find.byKey(Key('checkInAnswer_$field')), findsOneWidget);
    }
    expect(find.text('symptoms.checkIn.mild'.tr()), findsOneWidget);
    expect(find.text('78 bpm'), findsOneWidget);
    expect(find.text('124/80 mmHg'), findsOneWidget);
    expect(find.text('5 / 10'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Felt tired'), 80);
    expect(find.text('Felt tired'), findsOneWidget);
  });

  testWidgets('today\'s check-in shows the activity advice', (tester) async {
    await pumpApp(tester, host(CheckInResultView(result: _checkIn())));
    expect(find.byKey(const Key('activityGuidanceCard')), findsOneWidget);
  });

  testWidgets(
    'an older check-in from the history shows its date and no advice for '
    'today',
    (tester) async {
      final DateTime lastWeek = DateTime.now().subtract(const Duration(days: 7));
      await pumpApp(
        tester,
        host(
          CheckInResultView(
            result: _checkIn(at: lastWeek, worse: true),
            fromHistory: true,
          ),
        ),
      );

      expect(find.byKey(const Key('activityGuidanceCard')), findsNothing);
      expect(
        find.text('symptoms.summary.subtitle'.tr()),
        findsNothing,
        reason: 'the subtitle is the date, not "your symptoms today"',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('checkInAnswer_worse')),
        80,
      );
      expect(find.byKey(const Key('checkInAnswer_worse')), findsOneWidget);
    },
  );

  testWidgets('the details screen finds the check-in by its id', (
    tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const CheckInDetailScreen(id: 'c1'),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        symptomRepositoryProvider.overrideWithValue(_FakeRepo(<SymptomCheckIn>[
          _checkIn(),
        ])),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(CheckInResultView), findsOneWidget);
    expect(find.text('symptoms.history.detailTitle'.tr()), findsWidgets);
  });
}
