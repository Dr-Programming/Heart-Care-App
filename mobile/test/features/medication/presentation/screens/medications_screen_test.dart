import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medications_screen.dart';
import 'package:libu_care/features/medication/presentation/widgets/missed_run_alert.dart';

import '../../../../helpers/pump_app.dart';

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;

  @override
  Future<MedicationListState> build() async => _state;
}

Medication _medication(String id) => Medication(
  clientRecordId: id, serverId: null, name: 'Aspirin', doseMg: 75,
  frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
  active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
);

void main() {
  setUpWidgetTests();

  testWidgets('shows an empty state with no medications', (tester) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[])),
        ),
      ],
    );

    // The `meds` translation namespace is still `{}` (Task 20 fills it in),
    // so `.tr()` falls back to rendering the literal key string rather than
    // throwing — asserting on that literal text would just be testing
    // easy_localization's fallback behaviour, not this screen. Assert on the
    // widget type instead: translation-independent, and still verifies the
    // empty-medications branch actually rendered `EmptyState`.
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(MedicationsScreen), findsOneWidget);
  });

  testWidgets('shows today\'s doses and the medication list when loaded', (tester) async {
    const ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
      scheduledDate: '2026-08-25', scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending, doseLog: null,
    );
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(todaysDoses: const <ScheduledDose>[dose], medications: <Medication>[_medication('m1')]),
          ),
        ),
      ],
    );

    expect(find.textContaining('Aspirin'), findsWidgets);
  });

  testWidgets('renders the consecutive-miss alert when one is raised (I2)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(
              todaysDoses: const <ScheduledDose>[],
              medications: <Medication>[_medication('m1')],
              missedRunAlerts: <Medication>[_medication('m1')],
            ),
          ),
        ),
      ],
    );

    expect(find.byType(MissedRunAlert), findsOneWidget);
    expect(find.text('meds.alert.missedRunTitle'.tr()), findsOneWidget);
    expect(
      find.text(
        'meds.alert.missedRunBody'.tr(
          namedArgs: const <String, String>{'name': 'Aspirin'},
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders no alert when there is no missed run (I2)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(
              todaysDoses: const <ScheduledDose>[],
              medications: <Medication>[_medication('m1')],
            ),
          ),
        ),
      ],
    );

    expect(find.byType(MissedRunAlert), findsNothing);
  });

  testWidgets(
    'renders in Amharic without overflowing, alert and all (I9)',
    (tester) async {
      // Bilingual UI is a hard project constraint and Amharic strings run
      // longer than their English counterparts, which is exactly what breaks
      // a fixed-width row. This is the slice's Amharic smoke test.
      const ScheduledDose dose = ScheduledDose(
        medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
        scheduledDate: '2026-08-25', scheduledTime: '08:00',
        status: ScheduledDoseStatus.pending, doseLog: null,
      );

      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              MedicationListState(
                todaysDoses: const <ScheduledDose>[dose],
                medications: <Medication>[_medication('m1')],
                missedRunAlerts: <Medication>[_medication('m1')],
              ),
            ),
          ),
        ],
        language: AppLanguage.am,
      );

      // Real Amharic, not the English fallback and not the raw key.
      final String title = 'meds.title'.tr();
      expect(title, isNot('Medications'));
      expect(title, isNot('meds.title'));
      expect(find.text(title), findsOneWidget);
      expect(find.text('meds.alert.missedRunTitle'.tr()), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
