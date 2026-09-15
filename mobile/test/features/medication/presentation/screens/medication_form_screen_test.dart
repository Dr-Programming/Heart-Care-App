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

    await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
    await tester.tap(find.text('meds.form.reviewButton'.tr()));
    await tester.pump();

    expect(find.text('meds.errors.nameRequired'.tr()), findsOneWidget);
  });

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

      tester.view.physicalSize = const Size(400, 400);
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
      );

      expect(tester.takeException(), isNull);
    },
  );

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Atorvastatin');
    await tester.enterText(find.byType(TextField).at(1), '20');

    await tester.pump();
    await tester.ensureVisible(find.text('meds.frequency.onceDaily'.tr()));
    await tester.tap(find.text('meds.frequency.onceDaily'.tr()));
    await tester.pump();
  }

  testWidgets(
    'a valid form pushes ReviewMedicationScreen when Save is tapped, '
    'without saving immediately',
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
        ],
      );

      await fillValidForm(tester);

      await tester.ensureVisible(find.text('meds.form.reviewButton'.tr()));
      await tester.tap(find.text('meds.form.reviewButton'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewMedicationScreen), findsOneWidget);

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

      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextField).at(2));
      await tester.enterText(find.byType(TextField).at(2), '+251900000000');
      await tester.pumpAndSettle();

      final CaregiverNotifySettings saved = await store.get('m1');
      expect(saved.enabled, isTrue);
      expect(saved.phone, '+251900000000');
    },
  );

  testWidgets(
    'add mode leaves the caregiver toggle and phone field fully enabled',
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

      final SwitchListTile toggle = tester.widget(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, isFalse);

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
    'same as add mode',
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

      expect(
        find.widgetWithText(AppTextField, 'meds.form.caregiverPhone'.tr()),
        findsNothing,
      );

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

  Finder doseChips() => find.byWidgetPredicate(
    (Widget w) =>
        w is ActionChip &&
        w.label is Text &&
        ((w.label as Text).data?.endsWith(' mg') ?? false),
  );

  group('dose quick-pick chips', () {
    testWidgets(
      'typing a known medication name shows its library doses as chips, '
      'and tapping one fills the dose field',
      (tester) async {
        await pumpApp(tester, const MedicationFormScreen());

        expect(doseChips(), findsNothing);

        await tester.enterText(find.byType(TextField).at(0), 'Metoprolol');
        await tester.pump();

        expect(find.widgetWithText(ActionChip, '25 mg'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '50 mg'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '100 mg'), findsOneWidget);
        expect(doseChips(), findsNWidgets(3));

        await tester.tap(find.widgetWithText(ActionChip, '50 mg'));
        await tester.pump();

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
      'add mode leaves the instructions chips fully interactive',
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

        final ChoiceChip afterMeal = tester.widget(
          find.widgetWithText(ChoiceChip, 'meds.form.instructions.afterMeal'.tr()),
        );
        expect(afterMeal.onSelected, isNotNull);
        expect(afterMeal.selected, isFalse);

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

  testWidgets(
    'renders the whole form in real Amharic on a phone-sized screen (I9)',
    (tester) async {

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
