import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication;
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/data/medication_instructions_store.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/review_medication_screen.dart';
import 'package:libu_care/features/medication/presentation/widgets/time_list_field.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';
import '../../helpers/fake_medication_repository.dart';

class _FakeFormController extends MedicationFormController {
  _FakeFormController(this._state);
  MedicationFormState _state;

  @override
  MedicationFormState build() => _state;

  @override
  void setName(String value) => state = _state = _state.copyWith(name: value);

  @override
  Future<bool> save({
    CaregiverNotifySettings? caregiverSettings,
    MedicationInstructions? instructions,
  }) async {
    _state = _state.copyWith(nameError: 'meds.errors.nameRequired');
    state = _state;
    return false;
  }
}

/// The form pushed onto a real (miniature) `GoRouter` stack.
///
/// `MedicationFormScreen` closes itself with `context.pop()` on deactivate
/// (the only remaining direct pop it does — Save now pushes
/// `ReviewMedicationScreen` instead of closing this screen itself), which
/// needs a GoRouter above it and something underneath to pop back to. Two
/// nested routes give it both, and let a test assert that the screen
/// actually closed rather than only that the controller was called.
Widget _routedForm({String? editingId}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/edit',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('behind the form')),
          routes: <RouteBase>[
            GoRoute(
              path: 'edit',
              builder: (BuildContext _, GoRouterState _) =>
                  MedicationFormScreen(editingId: editingId),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Records what the deactivate action asked the list controller to do.
class _SpyListController extends MedicationListController {
  String? deactivatedId;

  @override
  Future<MedicationListState> build() async => const MedicationListState(
    todaysDoses: <ScheduledDose>[],
    medications: <Medication>[],
  );

  @override
  Future<void> deactivate(String clientRecordId) async {
    deactivatedId = clientRecordId;
  }
}

void main() {
  setUpWidgetTests();

  testWidgets('shows a validation error after an empty save attempt', (tester) async {
    await pumpApp(
      tester,
      const MedicationFormScreen(),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(
          () => _FakeFormController(const MedicationFormState()),
        ),
      ],
    );

    // Fix round 1 added a disabled phone field + note in add mode, which
    // pushes Save below the fold on the default 800x600 test surface — the
    // same reason the deactivate-button tests below already `ensureVisible`
    // before tapping.
    await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
    await tester.tap(find.text('meds.form.reviewButton'.tr()));
    await tester.pump();

    expect(find.text('meds.errors.nameRequired'.tr()), findsOneWidget);
  });

  // Fix 2 of the second Figma follow-up wave: the bottom button does not
  // save — it navigates to ReviewMedicationScreen, which owns the real
  // "Save medication" action — so it must say "Review & confirm", with a
  // trailing arrow, rather than "Save".
  testWidgets(
    'the bottom button reads "Review & confirm" with a trailing arrow icon, '
    'not "Save"',
    (tester) async {
      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
        ],
      );

      expect(find.text('meds.form.reviewButton'.tr()), findsOneWidget);
      expect(find.text('common.save'.tr()), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    },
  );

  testWidgets(
    'does not overflow on a short viewport (e.g. a small device, or the '
    'keyboard open while editing)',
    (tester) async {
      // Before the fix (plain `AppScaffold(title:, body:)`, which defaults
      // `scrollable: false`), an un-scrolled Column holding two text fields,
      // a Wrap of frequency chips, TimeListField's own label + chip row, and
      // the save button overflows vertically once the viewport is shorter
      // than its natural content height — exactly what a small device or an
      // open soft keyboard does. 400x400 logical px (well under any real
      // phone's available content height once the AppBar and status bar are
      // subtracted) reproduces that squeeze.
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // TID + three schedule times maximizes the form's natural content
      // height (more chips in TimeListField) so this is the worst case the
      // form realistically renders, not just the empty default state.
      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(
              const MedicationFormState(
                frequency: MedicationFrequency.tid,
                scheduleTimes: <String>['08:00', '14:00', '20:00'],
              ),
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
    },
  );

  /// Fills the add form with a valid medication.
  ///
  /// Tapping the "once daily" chip is what populates `scheduleTimes` (via
  /// `setFrequency`'s suggested defaults), so the form passes validation.
  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
    await tester.enterText(find.byType(TextField).at(1), '20');
    // "Atorvastatin" is in the medication library, so the Name field's own
    // inline suggestion list would render below it while the Dose field is
    // still blank — but it's gone as of the line above (that suggestion
    // list hides itself once `state.doseMg` is non-blank, see
    // `medication_form_screen.dart`). This `pump()` lets that disappearance
    // actually settle into the tree before `ensureVisible` measures where
    // "Once daily" now sits — without it, `ensureVisible` can scroll to the
    // chip's *pre*-disappearance position, which the still-pending rebuild
    // then shifts out from under the following `tap()`.
    await tester.pump();
    await tester.ensureVisible(find.text('meds.frequency.onceDaily'.tr()));
    await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
    await tester.pump();
  }

  testWidgets(
    'a valid form pushes ReviewMedicationScreen when Save is tapped, '
    'without saving immediately',
    (tester) async {
      // Before the M3 Figma rework, tapping Save called `controller.save()`
      // directly. Now it only validates and navigates — the actual save (and
      // its I7 error handling) belongs to `ReviewMedicationScreen`, already
      // covered by review_medication_screen_test.dart.
      final FakeMedicationRepository repository = FakeMedicationRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);

      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(repository),
          medicationNotificationsProvider.overrideWithValue(
            MedicationNotifications(RecordingScheduler(), db.preferencesDao),
          ),
        ],
      );

      await fillValidForm(tester);
      // Fix round 1's add-mode disabled phone field + note pushes Save below
      // the fold on the default test surface.
      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewMedicationScreen), findsOneWidget);
      // `skipOffstage: false`: `MedicationFormScreen` is still mounted
      // underneath `ReviewMedicationScreen` (it wasn't popped, only covered)
      // — but the default finder skips exactly that offstage/covered route,
      // so the default `find.byType` would report 0 matches here even though
      // the widget genuinely never left the tree.
      expect(
        find.byType(MedicationFormScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        repository.medications,
        isEmpty,
        reason: 'Save must not persist anything until Review confirms',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an invalid form (never touched) shows validation errors instead of '
    'opening the review screen',
    (tester) async {
      await pumpApp(tester, const MedicationFormScreen());

      // Fix round 1's add-mode disabled phone field + note pushes Save below
      // the fold on the default test surface.
      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('meds.errors.nameRequired'.tr()), findsOneWidget);
      expect(find.byType(ReviewMedicationScreen), findsNothing);
    },
  );

  testWidgets('offers no deactivate action in add mode (C3)', (tester) async {
    await pumpApp(
      tester,
      const MedicationFormScreen(),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(
          () => _FakeFormController(const MedicationFormState()),
        ),
      ],
    );

    expect(find.text('meds.deactivate'.tr()), findsNothing);
  });

  testWidgets(
    'deactivating in edit mode confirms first, then deactivates that '
    'medication (C3)',
    (tester) async {
      final _SpyListController listController = _SpyListController();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
          medicationListControllerProvider.overrideWith(() => listController),
          // Edit mode now also loads caregiver-notify settings and
          // instructions for 'm1' alongside the medication itself, so both
          // need a real (in-memory) store rather than hitting the real
          // on-device `appDatabaseProvider`.
          caregiverNotifyStoreProvider.overrideWithValue(
            CaregiverNotifyStore(db.preferencesDao),
          ),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );

      // The caregiver toggle above it pushes it further down the scrollable
      // form than the default 800x600 test surface shows without scrolling.
      await tester.ensureVisible(find.text('meds.deactivate'.tr()));
      await tester.tap(find.text('meds.deactivate'.tr()));
      await tester.pumpAndSettle();

      // Spec §3: the sheet has to say plainly that history is kept.
      expect(find.text('meds.deactivateTitle'.tr()), findsOneWidget);
      expect(find.text('meds.deactivateBody'.tr()), findsOneWidget);
      expect(listController.deactivatedId, isNull, reason: 'not yet confirmed');

      await tester.tap(find.text('meds.deactivateConfirm'.tr()));
      await tester.pumpAndSettle();

      expect(listController.deactivatedId, 'm1');
      expect(find.text('behind the form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing the confirm sheet deactivates nothing (C3)', (
    tester,
  ) async {
    final _SpyListController listController = _SpyListController();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);

    await pumpApp(
      tester,
      _routedForm(editingId: 'm1'),
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(
          FakeMedicationRepository(
            medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
          ),
        ),
        medicationFormControllerProvider.overrideWith(
          () => _FakeFormController(const MedicationFormState()),
        ),
        medicationListControllerProvider.overrideWith(() => listController),
        caregiverNotifyStoreProvider.overrideWithValue(
          CaregiverNotifyStore(db.preferencesDao),
        ),
        medicationInstructionsStoreProvider.overrideWithValue(
          MedicationInstructionsStore(db.preferencesDao),
        ),
      ],
    );

    await tester.ensureVisible(find.text('meds.deactivate'.tr()));
    await tester.tap(find.text('meds.deactivate'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();

    expect(listController.deactivatedId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edit mode loads previously saved caregiver-notify settings alongside '
    'the medication',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final CaregiverNotifyStore store = CaregiverNotifyStore(db.preferencesDao);
      await store.set(
        'm1',
        const CaregiverNotifySettings(enabled: true, phone: '+251911234567'),
      );

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(store),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );

      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
      expect(find.text('+251911234567'), findsOneWidget);
    },
  );

  testWidgets(
    'toggling caregiver notify and typing a phone in edit mode persists '
    'via CaregiverNotifyStore',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final CaregiverNotifyStore store = CaregiverNotifyStore(db.preferencesDao);

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(store),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );

      expect((await store.get('m1')).enabled, isFalse);

      // The taller banded header pushes the toggle below the fold on the
      // default test surface — same reason other taps in this file
      // already `ensureVisible` first.
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // The phone field only renders once the toggle is on — name (0) and
      // dose (1) are the other two `TextField`s on this form.
      await tester.ensureVisible(find.byType(TextField).at(2));
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pumpAndSettle();

      final CaregiverNotifySettings saved = await store.get('m1');
      expect(saved.enabled, isTrue);
      expect(saved.phone, '+251900000000');
    },
  );

  testWidgets(
    'add mode leaves the caregiver toggle and phone field fully enabled '
    '(third Figma follow-up)',
    (tester) async {
      // Fix round 1 disabled these in add mode, since `_persistCaregiverSettings`
      // had nothing to key `CaregiverNotifyStore` by yet — but that read as
      // being blocked from entering the information at all, per real user
      // feedback. `MedicationFormController.save()` now persists it once the
      // medication's real id exists (see that method's doc comment and
      // medications_screen_test.dart's full-add-flow coverage of the actual
      // persisted result); this screen-level test only needs to prove the
      // fields are genuinely interactive here, not that the write lands.
      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
        ],
      );

      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, isFalse);

      // The taller banded header (plus the gap now added below it, matching
      // Figma) pushes the toggle below the fold on the default test surface.
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

      final AppTextField phoneField = tester.widget(
        find.widgetWithText(AppTextField, 'meds.form.caregiverPhone'.tr()),
      );
      expect(phoneField.enabled, isTrue);

      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
        '+251900000000',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit mode leaves the caregiver toggle and phone field fully enabled, '
    'unaffected by the add-mode fix (fix round 1)',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final CaregiverNotifyStore store = CaregiverNotifyStore(db.preferencesDao);

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(const MedicationFormState()),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(store),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );

      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull);

      // Same as before this fix: the phone field stays hidden until the
      // toggle is switched on, rather than always showing (add mode only).
      expect(
        find.widgetWithText(AppTextField, 'meds.form.caregiverPhone'.tr()),
        findsNothing,
      );

      // The taller banded header (back arrow + title + subtitle, matching
      // Figma's real header on this screen) pushes the toggle below the
      // fold on the default 800x600 test surface — same reason other taps
      // in this file already `ensureVisible` first.
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final AppTextField phoneField = tester.widget(
        find.widgetWithText(AppTextField, 'meds.form.caregiverPhone'.tr()),
      );
      expect(phoneField.enabled, isTrue);

      await tester.ensureVisible(find.byType(TextField).at(2));
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pumpAndSettle();

      final CaregiverNotifySettings saved = await store.get('m1');
      expect(saved.enabled, isTrue);
      expect(saved.phone, '+251900000000');
      expect(tester.takeException(), isNull);
    },
  );

  // Fix 4 (I4) of the final-review fix wave: before Task 6, this file had a
  // test proving a successful save closes the form with no error shown,
  // using a real GoRouter-managed page underneath (deleted, no equivalent
  // added, when Save started pushing `ReviewMedicationScreen` instead of
  // saving directly). This is that test's equivalent for the two-screen
  // flow: `_routedForm(editingId:)` represents the real edit entry point
  // (`MedicationsScreen` -> the `medicationEdit` GoRoute -> this form), Save
  // on the form pushes `ReviewMedicationScreen` on top of the GoRouter
  // Navigator, and Save on Review triggers the real controller's save() and
  // its pop-up-to-two-levels listener — proving that logic genuinely pops
  // back through a go_router-managed `Page`, not just a plain
  // `MaterialPageRoute` stack (the add flow already covers that case above).
  testWidgets(
    'edit flow: saving from the review screen closes both screens with no '
    'error and lands back on the screen behind the form',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
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

      // `fakeMedication`'s defaults are already valid, so no field needs
      // editing — this only has to prove the navigation/save plumbing.
      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

      await tester.tap(find.text('meds.review.save'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ReviewMedicationScreen), findsNothing);
      expect(find.byType(MedicationFormScreen, skipOffstage: false), findsNothing);
      expect(find.text('behind the form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Fix 3 of the second Figma follow-up wave: quick-pick dose chips built
  // from `kMedicationLibrary`, reactive to the Name field.
  //
  // `find.byType(ActionChip)` alone isn't specific enough: `TimeListField`
  // (also rendered on this form) has its own permanent "Add" `ActionChip`
  // for adding a schedule time, so a blanket ActionChip search always finds
  // at least that one. This predicate scopes down to chips whose label looks
  // like a dose ("25 mg", "50 mg", ...), which nothing else on this form
  // renders.
  Finder doseChips() => find.byWidgetPredicate(
    (Widget w) =>
        w is ActionChip &&
        w.label is Text &&
        ((w.label as Text).data?.endsWith(' mg') ?? false),
  );

  group('dose quick-pick chips (Fix 3)', () {
    testWidgets(
      'typing a known medication name shows its library doses as chips, '
      'and tapping one fills the dose field',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        // No name typed yet — nothing to suggest chips for.
        expect(doseChips(), findsNothing);

        await tester.enterText(find.byType(TextField).at(0), 'Metoprolol');
        await tester.pump();

        // kMedicationLibrary's three Metoprolol doses, ascending, deduped.
        expect(find.widgetWithText(ActionChip, '25 mg'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '50 mg'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '100 mg'), findsOneWidget);
        expect(doseChips(), findsNWidgets(3));

        await tester.tap(find.widgetWithText(ActionChip, '50 mg'));
        await tester.pump();

        // Two checks, deliberately not just one: form state proves the chip
        // reuses `controller.setDoseMg` rather than a second source of
        // truth (the dose field's own error-clearing logic runs too), and
        // the rendered field text proves the fourth Figma follow-up's fix
        // actually shows it — the dose field is now bound to a real
        // `TextEditingController` precisely so this second assertion holds;
        // before that fix, state updated correctly but the field kept
        // showing nothing, which this exact test previously had no way to
        // catch.
        final MedicationFormState state = ProviderScope.containerOf(
          tester.element(find.byType(MedicationFormScreen)),
        ).read(medicationFormControllerProvider);
        expect(state.doseMg, '50');
        expect(
          tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
          '50',
        );
      },
    );

    testWidgets(
      'typing an unrecognized medication name shows no chip row',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        await tester.enterText(
          find.byType(TextField).at(0),
          'Zzz Not A Real Drug',
        );
        await tester.pump();

        expect(doseChips(), findsNothing);
      },
    );

    testWidgets(
      'the free-text dose field still works standalone with no name typed '
      '(regression)',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        expect(doseChips(), findsNothing);

        await tester.enterText(find.byType(TextField).at(1), '42');
        await tester.pump();

        final MedicationFormState state = ProviderScope.containerOf(
          tester.element(find.byType(MedicationFormScreen)),
        ).read(medicationFormControllerProvider);
        expect(state.doseMg, '42');
        expect(doseChips(), findsNothing);
      },
    );
  });

  // Requested directly by the user: "Enter manually" had no suggestions at
  // all, unlike MedicationSearchScreen's own search bar.
  group('name field suggestions (manual entry)', () {
    testWidgets('typing one letter shows no suggestions', (tester) async {
      await pumpApp(tester, const MedicationFormScreen());

      await tester.enterText(find.byType(TextField).at(0), 'M');
      await tester.pump();

      expect(find.text('Metoprolol 25 mg'), findsNothing);
    });

    testWidgets(
      'typing two or more letters shows matching library entries, capped '
      'at four, most-common first',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        // Substring, not prefix: "etoprolol" only appears mid-word in
        // "Metoprolol", proving this reuses `searchMedicationLibrary`'s own
        // case-insensitive substring match rather than a stricter one.
        // ("prolol" was tried first here and rejected — it also matches
        // "Bisoprolol", which pushes Metoprolol's own third dose past the
        // 4-item cap below; "etoprolol" matches only Metoprolol.)
        await tester.enterText(find.byType(TextField).at(0), 'etoprolol');
        await tester.pump();

        expect(find.text('Metoprolol 25 mg'), findsOneWidget);
        expect(find.text('Metoprolol 50 mg'), findsOneWidget);
        expect(find.text('Metoprolol 100 mg'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a suggestion fills both name and dose, and the list '
      'disappears',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        await tester.enterText(find.byType(TextField).at(0), 'prolol');
        await tester.pump();

        await tester.tap(find.text('Metoprolol 50 mg'));
        await tester.pump();

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
        // Gone, not just unchanged: a dose now exists, and this list hides
        // itself once it does (see medication_form_screen.dart's own
        // comment on why — no `focusNode` on `AppTextField` to hide it on
        // blur instead).
        expect(find.text('Metoprolol 25 mg'), findsNothing);
        expect(find.text('Metoprolol 100 mg'), findsNothing);
      },
    );

    testWidgets('typing an unrecognized name shows no suggestions', (tester) async {
      await pumpApp(tester, const MedicationFormScreen());

      await tester.enterText(find.byType(TextField).at(0), 'Zzz Not A Real Drug');
      await tester.pump();

      expect(find.byType(SectionCard), findsNothing);
    });

    testWidgets('never shows in edit mode, however the name is typed', (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);

      await pumpApp(
        tester,
        _routedForm(editingId: 'm1'),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(
            CaregiverNotifyStore(db.preferencesDao),
          ),
          medicationInstructionsStoreProvider.overrideWithValue(
            MedicationInstructionsStore(db.preferencesDao),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'prolol');
      await tester.pump();

      expect(find.text('Metoprolol 25 mg'), findsNothing);
      expect(find.byType(SectionCard), findsNothing);
    });
  });

  // Second Figma follow-up, Part A: the Instructions field.
  group('instructions field', () {
    testWidgets(
      'edit mode loads a previously saved instruction alongside the '
      'medication',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);
        final MedicationInstructionsStore store = MedicationInstructionsStore(
          db.preferencesDao,
        );
        await store.set('m1', MedicationInstructions.afterMeal);

        await pumpApp(
          tester,
          _routedForm(editingId: 'm1'),
          overrides: <Override>[
            medicationRepositoryProvider.overrideWithValue(
              FakeMedicationRepository(
                medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
              ),
            ),
            medicationFormControllerProvider.overrideWith(
              () => _FakeFormController(const MedicationFormState()),
            ),
            caregiverNotifyStoreProvider.overrideWithValue(
              CaregiverNotifyStore(db.preferencesDao),
            ),
            medicationInstructionsStoreProvider.overrideWithValue(store),
          ],
        );

        final ChoiceChip afterMeal = tester.widget(
          find.widgetWithText(ChoiceChip, 'meds.form.instructions.afterMeal'.tr()),
        );
        final ChoiceChip withFood = tester.widget(
          find.widgetWithText(ChoiceChip, 'meds.form.instructions.withFood'.tr()),
        );
        expect(afterMeal.selected, isTrue);
        expect(withFood.selected, isFalse);
      },
    );

    testWidgets(
      'tapping an instructions chip in edit mode persists via '
      'MedicationInstructionsStore, and tapping the same chip again '
      'deselects back to none',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);
        final MedicationInstructionsStore store = MedicationInstructionsStore(
          db.preferencesDao,
        );

        await pumpApp(
          tester,
          _routedForm(editingId: 'm1'),
          overrides: <Override>[
            medicationRepositoryProvider.overrideWithValue(
              FakeMedicationRepository(
                medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
              ),
            ),
            medicationFormControllerProvider.overrideWith(
              () => _FakeFormController(const MedicationFormState()),
            ),
            caregiverNotifyStoreProvider.overrideWithValue(
              CaregiverNotifyStore(db.preferencesDao),
            ),
            medicationInstructionsStoreProvider.overrideWithValue(store),
          ],
        );

        expect(await store.get('m1'), MedicationInstructions.none);

        // Below the fold on the default 800x600 test surface, same as the
        // caregiver phone field further up the form.
        await tester.ensureVisible(find.text('meds.form.instructions.withFood'.tr()));
        await tester.tap(find.text('meds.form.instructions.withFood'.tr()));
        await tester.pumpAndSettle();
        expect(await store.get('m1'), MedicationInstructions.withFood);
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'meds.form.instructions.withFood'.tr()),
              )
              .selected,
          isTrue,
        );

        // Tap-again-to-deselect.
        await tester.tap(find.text('meds.form.instructions.withFood'.tr()));
        await tester.pumpAndSettle();
        expect(await store.get('m1'), MedicationInstructions.none);
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'meds.form.instructions.withFood'.tr()),
              )
              .selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'add mode leaves the instructions chips fully interactive '
      '(third Figma follow-up)',
      (tester) async {
        // Same reasoning as the caregiver toggle/phone field's own
        // "add mode leaves ... fully enabled" test above — see its doc
        // comment. `MedicationInstructionsStore`'s write happens once
        // `MedicationFormController.save()` has a real id, proven end-to-end
        // in medications_screen_test.dart's full-add-flow coverage; this
        // screen-level test only needs the chip to genuinely respond to a
        // tap here.
        await pumpApp(
          tester,
          const MedicationFormScreen(),
          overrides: <Override>[
            medicationFormControllerProvider.overrideWith(
              () => _FakeFormController(const MedicationFormState()),
            ),
          ],
        );

        final ChoiceChip afterMeal = tester.widget(
          find.widgetWithText(ChoiceChip, 'meds.form.instructions.afterMeal'.tr()),
        );
        expect(afterMeal.onSelected, isNotNull);
        expect(afterMeal.selected, isFalse);

        // The taller banded header pushes the Instructions chips below the
        // fold on the default test surface.
        await tester.ensureVisible(find.text('meds.form.instructions.afterMeal'.tr()));
        await tester.tap(find.text('meds.form.instructions.afterMeal'.tr()));
        await tester.pump();
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'meds.form.instructions.afterMeal'.tr()),
              )
              .selected,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Second Figma follow-up, Part B: "As needed" is Custom frequency with an
  // empty schedule — no new enum value, no new persisted field. See
  // `MedicationFormController.validate()`'s doc comment for the binding
  // design constraint.
  group('"As needed" frequency', () {
    testWidgets(
      'tapping "As needed" clears the schedule times and hides the time '
      'picker, showing the disables-reminders caption instead',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        expect(find.byType(TimeListField), findsOneWidget);
        expect(find.text('meds.form.asNeededCaption'.tr()), findsNothing);

        await tester.tap(find.text('meds.frequency.asNeeded'.tr()));
        await tester.pump();

        expect(find.byType(TimeListField), findsNothing);
        expect(find.text('meds.form.asNeededCaption'.tr()), findsOneWidget);

        final MedicationFormState state = ProviderScope.containerOf(
          tester.element(find.byType(MedicationFormScreen)),
        ).read(medicationFormControllerProvider);
        expect(state.frequency, MedicationFrequency.custom);
        expect(state.scheduleTimes, isEmpty);

        // Exactly one of Custom/As needed is highlighted, never both.
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.asNeeded'.tr()))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.custom'.tr()))
              .selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'tapping "Custom" after "As needed" restores the time picker with a '
      'backfilled default time',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        await tester.tap(find.text('meds.frequency.asNeeded'.tr()));
        await tester.pump();
        expect(find.byType(TimeListField), findsNothing);

        await tester.tap(find.text('meds.frequency.custom'.tr()));
        await tester.pump();

        expect(find.byType(TimeListField), findsOneWidget);
        expect(find.text('meds.form.asNeededCaption'.tr()), findsNothing);
        expect(find.text('08:00'), findsOneWidget);

        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.custom'.tr()))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.asNeeded'.tr()))
              .selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'editing an existing medication with frequency Custom and an empty '
      'schedule loads with "As needed" selected, not "Custom"',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);

        await pumpApp(
          tester,
          _routedForm(editingId: 'm1'),
          overrides: <Override>[
            medicationRepositoryProvider.overrideWithValue(
              FakeMedicationRepository(
                medications: <Medication>[
                  fakeMedication(
                    clientRecordId: 'm1',
                    frequency: MedicationFrequency.custom,
                    scheduleTimes: const <String>[],
                  ),
                ],
              ),
            ),
            caregiverNotifyStoreProvider.overrideWithValue(
              CaregiverNotifyStore(db.preferencesDao),
            ),
            medicationInstructionsStoreProvider.overrideWithValue(
              MedicationInstructionsStore(db.preferencesDao),
            ),
          ],
        );

        expect(find.byType(TimeListField), findsNothing);
        expect(find.text('meds.form.asNeededCaption'.tr()), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.asNeeded'.tr()))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'meds.frequency.custom'.tr()))
              .selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'a form saved with "As needed" selected succeeds, and the review '
      'screen shows "As needed" rather than "Custom" with a blank line',
      (tester) async {
        final FakeMedicationRepository repository = FakeMedicationRepository();
        final AppDatabase db = testDatabase();
        addTearDown(db.close);

        await pumpApp(
          tester,
          const MedicationFormScreen(),
          overrides: <Override>[
            medicationRepositoryProvider.overrideWithValue(repository),
            medicationNotificationsProvider.overrideWithValue(
              MedicationNotifications(RecordingScheduler(), db.preferencesDao),
            ),
            // Save now always threads caregiver settings/instructions
            // through to the real save() (third Figma follow-up) — see
            // medications_screen_test.dart's matching override for why this
            // is required even though this test doesn't care about their
            // values.
            caregiverNotifyStoreProvider.overrideWithValue(
              CaregiverNotifyStore(db.preferencesDao),
            ),
            medicationInstructionsStoreProvider.overrideWithValue(
              MedicationInstructionsStore(db.preferencesDao),
            ),
          ],
        );

        await tester.enterText(find.byType(TextField).at(0), 'GTN spray');
        await tester.enterText(find.byType(TextField).at(1), '0.4');
        await tester.tap(find.text('meds.frequency.asNeeded'.tr()));
        await tester.pump();

        await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
        await tester.tap(find.text('meds.form.reviewButton'.tr()));
        await tester.pumpAndSettle();

        expect(find.byType(ReviewMedicationScreen), findsOneWidget);
        expect(find.text('meds.errors.scheduleRequired'.tr()), findsNothing);
        expect(find.text('meds.frequency.asNeeded'.tr()), findsOneWidget);
        expect(find.text('meds.frequency.custom'.tr()), findsNothing);
        expect(find.text('meds.review.noFixedSchedule'.tr()), findsOneWidget);

        await tester.tap(find.text('meds.review.save'.tr()));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
        expect(repository.medications, hasLength(1));
        expect(repository.medications.single.frequency, MedicationFrequency.custom);
        expect(repository.medications.single.scheduleTimes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Kept last in the file on purpose: `pumpApp(language:)` switches
  // easy_localization's singleton locale, which the bare `'key'.tr()` calls in
  // the tests above read.
  testWidgets(
    'renders the whole form in real Amharic on a phone-sized screen (I9)',
    (tester) async {
      // Bilingual UI is a hard project constraint (CLAUDE.md) and Amharic copy
      // runs longer than English, so the form — the slice's most label-dense
      // screen, with two field labels, four frequency chips and TimeListField
      // all competing for width — is where longer strings would show first.
      // 360x740 is a common low-end Android size.
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(
            () => _FakeFormController(
              const MedicationFormState(
                frequency: MedicationFrequency.tid,
                scheduleTimes: <String>['08:00', '14:00', '20:00'],
              ),
            ),
          ),
        ],
        language: AppLanguage.am,
      );

      // Real Amharic from assets/translations/am.json — not the English
      // fallback, and not the raw key.
      final String nameLabel = 'meds.form.name'.tr();
      final String tid = 'meds.frequency.tid'.tr();
      expect(nameLabel, isNot('Name'));
      expect(nameLabel, isNot('meds.form.name'));
      expect(tid, isNot('Three times daily'));

      expect(find.text('meds.form.title'.tr()), findsOneWidget);
      expect(find.text(nameLabel), findsOneWidget);
      expect(find.text(tid), findsOneWidget);
      expect(find.text('meds.form.reviewButton'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
