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

/// `MedicationsScreen` pushed onto a real (miniature) `GoRouter` stack, the
/// same pattern `medication_form_screen_test.dart` uses — the app-bar menu
/// (Task 7) navigates with `context.pushNamed`, which needs a real
/// `GoRouter` above it to resolve `AppRoutes.adherence` /
/// `AppRoutes.reminderSettings`. The destinations are plain placeholder
/// screens: this test is only proving the menu reaches the right route name,
/// not re-testing `AdherenceScreen`/`ReminderSettingsScreen` themselves.
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

    // The `meds` translation namespace is still `{}` (Task 20 fills it in),
    // so `.tr()` falls back to rendering the literal key string rather than
    // throwing — asserting on that literal text would just be testing
    // easy_localization's fallback behaviour, not this screen. Assert on the
    // widget type instead: translation-independent, and still verifies the
    // empty-medications branch actually rendered `EmptyState`.
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(MedicationsScreen), findsOneWidget);
  });

  // Fix 1 (I1) of the final-review fix wave: the empty state's "add" action
  // must go through the same search-first flow as the FAB, not straight to
  // a blank form.
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

      // 'meds.add'.tr() also labels the FAB (which stays visible even in the
      // empty state, since it lives on the scaffold rather than the body) —
      // so target the empty state's own `AppButton` specifically rather than
      // an ambiguous `find.text`.
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
      // The name/dose fields render without a `TextEditingController` (a
      // pre-existing quirk of this form, unchanged by this task — see
      // medication_form_screen.dart), so the prefill is verified against the
      // actual form state rather than rendered text.
      final MedicationFormState state = ProviderScope.containerOf(
        tester.element(find.byType(MedicationFormScreen)),
      ).read(medicationFormControllerProvider);
      expect(state.name, 'Metoprolol');
      expect(state.doseMg, '50');
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

    await tester.pageBack();
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

      // `MedicationsScreen` is pushed on top of a distinct app-root screen
      // rather than being the Navigator's own first route — the real app's
      // shape (medications sits under a bottom-tab shell, not at the
      // Navigator's root — see review_medication_screen.dart's doc comment).
      // This is what makes the test able to actually catch the popUntil bug:
      // the old `popUntil((route) => route.isFirst)` would pop straight past
      // MedicationsScreen to "app root" below, which is exactly what the
      // final assertions rule out.
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
          // `ReviewMedicationScreen`'s Save now always threads caregiver
          // settings/instructions through to `MedicationFormController.save()`
          // (third Figma follow-up), which persists them via these two
          // providers regardless of whether the test cares about their
          // values — without a real, working store behind them here, `save()`
          // would fall through to the default `caregiverNotifyStoreProvider`/
          // `medicationInstructionsStoreProvider`, which build a real
          // `AppDatabase` via `appDatabaseProvider` this test never sets up,
          // and hang.
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
      await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
      await tester.pump();
      // Fix round 1's add-mode disabled caregiver phone field + note pushes
      // Save below the fold on the default test surface.
      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

      await tester.tap(find.text('meds.review.save'.tr()));
      await tester.pumpAndSettle();

      // Exactly two pops (Review, then Form) — landed on MedicationsScreen,
      // not popped past it to "app root" (the old `popUntil(isFirst)` bug)
      // and not still short of it either.
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

  // Third Figma follow-up: the caregiver toggle/phone and Instructions
  // chips used to be disabled in add mode (no `clientRecordId` to key their
  // stores by yet) — real user feedback that this read as being blocked
  // from entering real information at all, not just deferred. This proves
  // the fix end-to-end: filled in during the add flow, they must actually
  // land in their stores once `MedicationFormController.save()` has a real
  // id to key them by, not just visually accept the input.
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
      await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
      await tester.pump();

      // Caregiver toggle + phone: must be genuinely interactive in add mode
      // now, not disabled.
      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull, reason: 'no longer disabled in add mode');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pump();

      // Instructions: must also be genuinely interactive in add mode now.
      await tester.ensureVisible(find.text('meds.form.instructions.afterMeal'.tr()));
      await tester.tap(find.text('meds.form.instructions.afterMeal'.tr()));
      await tester.pump();

      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

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

  // Fix 1 of the second Figma follow-up wave: the Today/Schedule/History
  // selected-tab fill must be AppColors.ink (Figma's convention for every
  // selected chip/tab in this flow), not AppColors.primary — orange is
  // reserved for primary action buttons only.
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
      // Selected-tab text must stay legible against the now-dark fill.
      expect(tabBar.labelColor, AppColors.surface);
    },
  );

  testWidgets(
    'switching to the Schedule tab shows the medication list (M3 Figma rework, Task 7)',
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

      // Today is the default tab — the Schedule tab's medication card isn't
      // reachable until it's actually selected.
      await tester.tap(find.text('meds.schedule'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(MedicationCard), findsOneWidget);
      expect(find.text('meds.yourMedications'.tr()), findsOneWidget);
    },
  );

  testWidgets(
    'switching to the History tab shows dose history content (M3 Figma rework, Task 7)',
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

      await tester.tap(find.text('meds.history.title'.tr()));
      await tester.pumpAndSettle();

      // A light integration check on DoseHistoryContent's already-tested
      // behaviour (dose_history_adherence_reminders_test.dart covers its
      // internals) — just confirming it's really the History tab's content.
      expect(find.byType(DoseHistoryContent), findsOneWidget);
      expect(find.text('meds.history.syncPending'.tr()), findsNothing);
    },
  );

  testWidgets(
    'the app-bar menu navigates to Adherence (M3 Figma rework, Task 7)',
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
    'the app-bar menu navigates to Reminder Settings (M3 Figma rework, Task 7)',
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
