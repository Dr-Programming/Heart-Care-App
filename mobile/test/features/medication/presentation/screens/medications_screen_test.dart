import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:flutter/material.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medications_screen.dart';
import 'package:libu_care/features/medication/presentation/widgets/missed_run_alert.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/fake_medication_repository.dart';

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
    'a note typed on a logged dose reaches the repository (I6, FR-MED-008)',
    (tester) async {
      // End-to-end for the note path: real `MedicationListController`, real
      // `DoseRow`/`DoseNoteSheet`, only the repository faked — so this proves
      // text the user actually typed lands in `logDose(note:)` rather than
      // stopping at the widget callback.
      final FakeMedicationRepository repository = FakeMedicationRepository(
        medications: <Medication>[_medication('m1')],
        todays: <ScheduledDose>[
          ScheduledDose(
            medicationClientRecordId: 'm1',
            medicationName: 'Aspirin',
            doseMg: 75,
            scheduledDate: '2026-08-25',
            scheduledTime: '08:00',
            status: ScheduledDoseStatus.logged,
            doseLog: DoseLog(
              clientRecordId: 'd1',
              serverId: null,
              medicationClientRecordId: 'm1',
              medicationServerId: null,
              status: DoseStatus.taken,
              scheduledDate: '2026-08-25',
              scheduledTime: '08:00',
              loggedAt: DateTime(2026, 8, 25, 8, 5),
              note: null,
            ),
          ),
        ],
      );

      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await tester.tap(find.text('meds.note.add'.tr()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Took it with food');
      await tester.tap(find.text('meds.note.save'.tr()));
      await tester.pumpAndSettle();

      expect(repository.history, hasLength(1));
      expect(repository.history.single.note, 'Took it with food');
      expect(repository.history.single.status, DoseStatus.taken);
      expect(repository.history.single.medicationClientRecordId, 'm1');
      expect(repository.history.single.scheduledDate, '2026-08-25');
      expect(repository.history.single.scheduledTime, '08:00');
      expect(tester.takeException(), isNull);
    },
  );

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
