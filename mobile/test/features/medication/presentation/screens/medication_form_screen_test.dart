import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication;
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/review_medication_screen.dart';

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
  Future<bool> save() async {
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

    await tester.tap(find.text('common.save'.tr()));
    await tester.pump();

    expect(find.text('meds.errors.nameRequired'.tr()), findsOneWidget);
  });

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
      await tester.tap(find.text('common.save'.tr()));
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

      await tester.tap(find.text('common.save'.tr()));
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
          // Edit mode now also loads caregiver-notify settings for 'm1'
          // alongside the medication itself, so this needs a real (in-memory)
          // store rather than hitting the real on-device `appDatabaseProvider`.
          caregiverNotifyStoreProvider.overrideWithValue(
            CaregiverNotifyStore(db.preferencesDao),
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
        ],
      );

      expect((await store.get('m1')).enabled, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // The phone field only renders once the toggle is on — name (0) and
      // dose (1) are the other two `TextField`s on this form.
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pumpAndSettle();

      final CaregiverNotifySettings saved = await store.get('m1');
      expect(saved.enabled, isTrue);
      expect(saved.phone, '+251900000000');
    },
  );

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
      expect(find.text('common.save'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
