import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication;
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';

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
/// `MedicationFormScreen` closes itself with `context.pop()` — on save and on
/// deactivate — which needs a GoRouter above it and something underneath to
/// pop back to. Two nested routes give it both, and let a test assert that the
/// screen actually closed rather than only that the controller was called.
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

  /// Fills the add form with a valid medication and presses Save.
  ///
  /// Tapping the "once daily" chip is what populates `scheduleTimes` (via
  /// `setFrequency`'s suggested defaults), so the form passes validation and
  /// the save actually reaches the repository — which is the point of the
  /// tests below.
  Future<void> fillAndSave(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
    await tester.pump();
    await tester.tap(find.text('common.save'.tr()));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed save tells the user, in the failure\'s own words (I7)', (
    tester,
  ) async {
    // Before the fix, `AppButton.onPressed` was handed `controller.save`
    // directly — a `VoidCallback` swallowing a `Future<bool>` that rethrows on
    // failure. The rethrow became an unhandled async error: nothing shown to
    // the user, and `tester.takeException()` picking it up here.
    await pumpApp(
      tester,
      const MedicationFormScreen(),
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(
          FakeMedicationRepository(
            writeError: const NetworkFailure('No connection right now'),
          ),
        ),
      ],
    );

    await fillAndSave(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No connection right now'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the save failure must be handled, not left unhandled',
    );
  });

  testWidgets(
    'a non-Failure save error falls back to the generic message (I7)',
    (tester) async {
      // A raw `StateError.toString()` is an internal detail, not copy for a
      // patient — the screen substitutes the translated generic message.
      await pumpApp(
        tester,
        const MedicationFormScreen(),
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(
            FakeMedicationRepository(
              writeError: StateError('simulated local write failure'),
            ),
          ),
        ],
      );

      await fillAndSave(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('errors.generic'.tr()), findsOneWidget);
      expect(find.textContaining('simulated local write failure'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a save that succeeds shows no error and closes the form (I7)', (
    tester,
  ) async {
    // The counterpart to the two failure cases: the new error handling must
    // not fire on the happy path. Pumped on the miniature router because a
    // successful save pops the screen, and the notification scheduler is
    // faked because the real one reaches for a platform plugin that does not
    // exist under `flutter test`.
    final AppDatabase db = testDatabase();
    addTearDown(db.close);

    await pumpApp(
      tester,
      _routedForm(),
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(
          FakeMedicationRepository(),
        ),
        medicationNotificationsProvider.overrideWithValue(
          MedicationNotifications(RecordingScheduler(), db.preferencesDao),
        ),
      ],
    );

    await fillAndSave(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('behind the form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        ],
      );

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
      ],
    );

    await tester.tap(find.text('meds.deactivate'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();

    expect(listController.deactivatedId, isNull);
    expect(tester.takeException(), isNull);
  });
}
