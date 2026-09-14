import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication, DoseLog;
import 'package:libu_care/core/localization/language.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/data/medication_instructions_store.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/dose_history_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_search_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/medications_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/review_medication_screen.dart';
import 'package:libu_care/features/medication/presentation/widgets/medication_card.dart';
import 'package:libu_care/features/medication/presentation/widgets/missed_run_alert.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';
import '../../helpers/fake_medication_repository.dart';

class _FakeDoseHistoryController extends DoseHistoryController {
  _FakeDoseHistoryController(this._state);
  final DoseHistoryState _state;

  @override
  Future<DoseHistoryState> build() async => _state;
}

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

Widget _routedMedicationsScreen() {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/medications',
      routes: <RouteBase>[
        GoRoute(
          path: '/medications',
          name: AppRoutes.medications,
          builder: (BuildContext _, GoRouterState _) => const MedicationsScreen(),
        ),
        GoRoute(
          path: '/medications/adherence',
          name: AppRoutes.adherence,
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('adherence destination')),
        ),
        GoRoute(
          path: '/medications/reminders',
          name: AppRoutes.reminderSettings,
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('reminder settings destination')),
        ),
      ],
    ),
  );
}

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

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(MedicationsScreen), findsOneWidget);
  });

  testWidgets(
    'renders no AppBar at all -- MedicationsScreen is a tab root with '
    'nothing to pop back to, and the overflow menu lives inside the band',
    (tester) async {
      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
        ],
      );

      expect(find.byType(AppBar), findsNothing);

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the empty state\'s add action opens the search screen, not a '
    'blank form',
    (tester) async {
      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
        ],
      );

      expect(find.byType(EmptyState), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'meds.add'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationSearchScreen), findsOneWidget);
      expect(find.byType(MedicationFormScreen), findsNothing);
    },
  );

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

  testWidgets('tapping "+" opens the search screen', (tester) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
          ),
        ),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(MedicationSearchScreen), findsOneWidget);
  });

  testWidgets(
    'picking a search suggestion opens the form pre-filled from that entry',
    (tester) async {
      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
        ],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Metoprolol');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metoprolol 50 mg'));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationFormScreen), findsOneWidget);
      final MedicationFormState state = ProviderScope.containerOf(
        tester.element(find.byType(MedicationFormScreen)),
      ).read(medicationFormControllerProvider);
      expect(state.name, 'Metoprolol');
      expect(state.doseMg, '50');

      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'Metoprolol',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '50',
      );
    },
  );

  testWidgets('tapping Enter manually opens a blank form', (tester) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
          ),
        ),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('common.enterManually'.tr()));
    await tester.pumpAndSettle();

    expect(find.byType(MedicationFormScreen), findsOneWidget);
    final MedicationFormState state = ProviderScope.containerOf(
      tester.element(find.byType(MedicationFormScreen)),
    ).read(medicationFormControllerProvider);
    expect(state.name, isEmpty);
    expect(state.doseMg, isEmpty);
  });

  testWidgets('pressing back on the search screen returns to MedicationsScreen with no further navigation', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
          ),
        ),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationSearchScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(MedicationSearchScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(MedicationsScreen), findsOneWidget);
    expect(find.byType(MedicationSearchScreen), findsNothing);
    expect(find.byType(MedicationFormScreen), findsNothing);
  });

  testWidgets(
    'the full add flow (FAB -> search -> form -> review -> save) lands '
    'back on MedicationsScreen, not deeper or shallower',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final FakeMedicationRepository repository = FakeMedicationRepository();

      await pumpApp(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const MedicationsScreen()),
                ),
                child: const Text('app root'),
              ),
            ),
          ),
        ),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
          medicationRepositoryProvider.overrideWithValue(repository),
          medicationNotificationsProvider.overrideWithValue(
            MedicationNotifications(RecordingScheduler(), db.preferencesDao),
          ),

          caregiverNotifyStoreProvider.overrideWithValue(
            CaregiverNotifyStore(db.preferencesDao),
          ),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );

      await tester.tap(find.text('app root'));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationsScreen), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationSearchScreen), findsOneWidget);

      await tester.tap(find.text('common.enterManually'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationFormScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
      await tester.enterText(find.byType(TextField).at(1), '20');

      await tester.pump();
      await tester.ensureVisible(find.text('meds.frequency.onceDaily'.tr()));
      await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
      await tester.pump();

      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

      await tester.tap(find.text('meds.review.save'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationsScreen), findsOneWidget);
      expect(find.text('app root'), findsNothing);
      expect(find.byType(ReviewMedicationScreen), findsNothing);
      expect(find.byType(MedicationFormScreen), findsNothing);
      expect(find.byType(MedicationSearchScreen), findsNothing);
      expect(repository.medications, hasLength(1));
      expect(repository.medications.single.name, 'Atorvastatin');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the full add flow persists caregiver settings and instructions, '
    'entered while there was still no clientRecordId to key them by',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final FakeMedicationRepository repository = FakeMedicationRepository();
      final CaregiverNotifyStore caregiverStore = CaregiverNotifyStore(db.preferencesDao);
      final MedicationInstructionsStore instructionsStore = MedicationInstructionsStore(
        db.preferencesDao,
      );

      await pumpApp(
        tester,
        const MedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
          medicationRepositoryProvider.overrideWithValue(repository),
          medicationNotificationsProvider.overrideWithValue(
            MedicationNotifications(RecordingScheduler(), db.preferencesDao),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(caregiverStore),
          medicationInstructionsStoreProvider.overrideWithValue(instructionsStore),
        ],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.enterManually'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationFormScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
      await tester.enterText(find.byType(TextField).at(1), '20');

      await tester.pump();
      await tester.ensureVisible(find.text('meds.frequency.onceDaily'.tr()));
      await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
      await tester.pump();

      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull, reason: 'no longer disabled in add mode');

      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).at(2));
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pump();

      await tester.ensureVisible(find.text('meds.form.instructions.afterMeal'.tr()));
      await tester.tap(find.text('meds.form.instructions.afterMeal'.tr()));
      await tester.pump();

      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

      await tester.ensureVisible(find.text('meds.review.save'.tr()));
      await tester.tap(find.text('meds.review.save'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationsScreen), findsOneWidget);
      expect(repository.medications, hasLength(1));
      final String newId = repository.medications.single.clientRecordId;

      final CaregiverNotifySettings savedCaregiver = await caregiverStore.get(newId);
      expect(savedCaregiver.enabled, isTrue);
      expect(savedCaregiver.phone, '+251900000000');

      final MedicationInstructions savedInstructions = await instructionsStore.get(newId);
      expect(savedInstructions, MedicationInstructions.afterMeal);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders in Amharic without overflowing, alert and all (I9)',
    (tester) async {

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

      final String title = 'meds.title'.tr();
      expect(title, isNot('Medications'));
      expect(title, isNot('meds.title'));
      expect(find.text(title), findsOneWidget);
      expect(find.text('meds.alert.missedRunTitle'.tr()), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "the tab bar's selected-tab fill uses AppColors.ink, not AppColors.primary",
    (tester) async {
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

      final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final BoxDecoration indicator = tabBar.indicator! as BoxDecoration;
      expect(indicator.color, AppColors.ink);
      expect(indicator.color, isNot(AppColors.primary));

      expect(tabBar.labelColor, AppColors.surface);
    },
  );

  testWidgets(
    'switching to the Schedule tab shows the medication list',
    (tester) async {
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

      await tester.tap(find.text('meds.schedule'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationCard), findsOneWidget);
      expect(find.text('meds.yourMedications'.tr()), findsOneWidget);
    },
  );

  testWidgets(
    'switching to the History tab shows dose history content',
    (tester) async {
      final _FakeDoseHistoryController historyController = _FakeDoseHistoryController(
        DoseHistoryState(
          entries: <DoseHistoryEntry>[
            DoseHistoryEntry(
              log: DoseLog(
                clientRecordId: 'd1',
                serverId: null,
                medicationClientRecordId: 'm1',
                medicationServerId: null,
                status: DoseStatus.taken,
                scheduledDate: '2026-08-25',
                scheduledTime: '08:00',
                loggedAt: DateTime.utc(2026, 8, 25),
                note: null,
              ),
              medicationName: 'Aspirin',
              syncStatus: null,
            ),
          ],
          medications: <Medication>[_medication('m1')],
          filter: const DoseHistoryFilter(),
        ),
      );

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
          doseHistoryControllerProvider.overrideWith(() => historyController),
        ],
      );

      await tester.tap(find.text('meds.historyTab'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(DoseHistoryContent), findsOneWidget);
      expect(find.text('meds.history.syncPending'.tr()), findsNothing);
    },
  );

  testWidgets(
    'the app-bar menu navigates to Adherence',
    (tester) async {
      await pumpApp(
        tester,
        _routedMedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
        ],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('meds.adherence.title'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('adherence destination'), findsOneWidget);
    },
  );

  testWidgets(
    'the app-bar menu navigates to Reminder Settings',
    (tester) async {
      await pumpApp(
        tester,
        _routedMedicationsScreen(),
        overrides: <Override>[
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
            ),
          ),
        ],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('meds.reminders.title'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('reminder settings destination'), findsOneWidget);
    },
  );
}
