import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/review_medication_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/fake_medication_repository.dart';

class _FakeSavingController extends MedicationFormController {
  _FakeSavingController(this._state);
  MedicationFormState _state;
  bool saveCalled = false;

  @override
  MedicationFormState build() => _state;

  @override
  Future<bool> save() async {
    saveCalled = true;
    _state = _state.copyWith(saved: true);
    state = _state;
    return true;
  }
}

/// Loads real (prefilled) state but otherwise defers to the real
/// `MedicationFormController.save()` — used by the error-handling tests
/// below so they exercise the screen's actual `catch` block against a
/// genuine save failure, not a stubbed one.
class _PrefilledFormController extends MedicationFormController {
  _PrefilledFormController(this._initial);
  final MedicationFormState _initial;

  @override
  MedicationFormState build() => _initial;
}

void main() {
  setUpWidgetTests();

  const state = MedicationFormState(
    name: 'Metoprolol',
    doseMg: '50',
    frequency: MedicationFrequency.bid,
    scheduleTimes: <String>['08:00', '20:00'],
  );

  testWidgets('shows the entered name, dose, frequency and times', (tester) async {
    await pumpApp(
      tester,
      const ReviewMedicationScreen(notifyCaregiverEnabled: false),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => _FakeSavingController(state)),
      ],
    );

    expect(find.textContaining('Metoprolol'), findsWidgets);
    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('08:00'), findsWidgets);
  });

  testWidgets('Save medication calls the controller\'s save()', (tester) async {
    final fake = _FakeSavingController(state);
    await pumpApp(
      tester,
      const ReviewMedicationScreen(notifyCaregiverEnabled: false),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => fake),
      ],
    );

    await tester.tap(find.text('meds.review.save'.tr()));
    await tester.pumpAndSettle();

    expect(fake.saveCalled, isTrue);
  });

  // The two tests below drive the *real* `MedicationFormController.save()`
  // (not a stub) against a `FakeMedicationRepository` configured to throw —
  // confirming this screen's own `_save` reproduces `MedicationFormScreen`'s
  // I7 error handling exactly: a `Failure`'s own message verbatim, or the
  // `errors.generic` translation for anything else, in a `SnackBar`, with
  // no unhandled async error escaping the tap.
  testWidgets('a failed save shows the failure\'s own message in a SnackBar (I7)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ReviewMedicationScreen(notifyCaregiverEnabled: false),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => _PrefilledFormController(state)),
        medicationRepositoryProvider.overrideWithValue(
          FakeMedicationRepository(
            writeError: const NetworkFailure('No connection right now'),
          ),
        ),
      ],
    );

    await tester.tap(find.text('meds.review.save'.tr()));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No connection right now'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the save failure must be handled, not left unhandled',
    );
  });

  testWidgets('a non-Failure save error falls back to the generic message (I7)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ReviewMedicationScreen(notifyCaregiverEnabled: false),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => _PrefilledFormController(state)),
        medicationRepositoryProvider.overrideWithValue(
          FakeMedicationRepository(
            writeError: StateError('simulated local write failure'),
          ),
        ),
      ],
    );

    await tester.tap(find.text('meds.review.save'.tr()));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('errors.generic'.tr()), findsOneWidget);
    expect(find.textContaining('simulated local write failure'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Fix 2 (I2) of the final-review fix wave: the caregiver on/off row and
  // the "reminders set" banner copy, both previously missing.
  testWidgets(
    'shows the caregiver notify row as On when notifyCaregiverEnabled is true',
    (tester) async {
      await pumpApp(
        tester,
        const ReviewMedicationScreen(notifyCaregiverEnabled: true),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(() => _FakeSavingController(state)),
        ],
      );

      expect(find.text('meds.review.notifyCaregiver'.tr()), findsOneWidget);
      expect(find.text('meds.review.notifyCaregiverOn'.tr()), findsOneWidget);
      expect(find.text('meds.review.notifyCaregiverOff'.tr()), findsNothing);
    },
  );

  testWidgets(
    'shows the caregiver notify row as Off when notifyCaregiverEnabled is false',
    (tester) async {
      await pumpApp(
        tester,
        const ReviewMedicationScreen(notifyCaregiverEnabled: false),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(() => _FakeSavingController(state)),
        ],
      );

      expect(find.text('meds.review.notifyCaregiver'.tr()), findsOneWidget);
      expect(find.text('meds.review.notifyCaregiverOff'.tr()), findsOneWidget);
      expect(find.text('meds.review.notifyCaregiverOn'.tr()), findsNothing);
    },
  );

  testWidgets(
    'the banner shows "reminders set" copy with the joined schedule times '
    'alongside the offline note',
    (tester) async {
      await pumpApp(
        tester,
        const ReviewMedicationScreen(notifyCaregiverEnabled: false),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(() => _FakeSavingController(state)),
        ],
      );

      final String expected = 'meds.review.remindersSet'.tr(
        namedArgs: <String, String>{'times': state.scheduleTimes.join(', ')},
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text('meds.review.offlineNote'.tr()), findsOneWidget);
    },
  );

  // Fix 3 (I3): `_SummaryRow`'s value `Text` must be flex-guarded, matching
  // the unwrapped-leading / `Flexible`-trailing idiom `DoseRow` and
  // `MedicationCard` already use elsewhere in this feature.
  testWidgets(
    'does not overflow with several Custom-frequency schedule times at a '
    'narrow width',
    (tester) async {
      // Before the fix (`_SummaryRow`'s bare, unwrapped value `Text` in a
      // `spaceBetween` `Row`), a long joined schedule-times value on a narrow
      // device throws a `RenderFlex overflowed` FlutterError during pump.
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const customState = MedicationFormState(
        name: 'A medication with a fairly long name',
        doseMg: '50',
        frequency: MedicationFrequency.custom,
        scheduleTimes: <String>['06:00', '10:00', '14:00', '18:00', '22:00'],
      );

      await pumpApp(
        tester,
        const ReviewMedicationScreen(notifyCaregiverEnabled: true),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(() => _FakeSavingController(customState)),
        ],
      );

      expect(tester.takeException(), isNull);
    },
  );

  // Kept last in the file on purpose: `pumpApp(language:)` switches
  // easy_localization's singleton locale, which the bare `'key'.tr()` calls
  // in the tests above read.
  testWidgets(
    'does not overflow with several Custom-frequency schedule times in '
    'Amharic on a narrow width (I9)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const customState = MedicationFormState(
        name: 'A medication with a fairly long name',
        doseMg: '50',
        frequency: MedicationFrequency.custom,
        scheduleTimes: <String>['06:00', '10:00', '14:00', '18:00', '22:00'],
      );

      await pumpApp(
        tester,
        const ReviewMedicationScreen(notifyCaregiverEnabled: true),
        overrides: <Override>[
          medicationFormControllerProvider.overrideWith(() => _FakeSavingController(customState)),
        ],
        language: AppLanguage.am,
      );

      final String notifyOn = 'meds.review.notifyCaregiverOn'.tr();
      expect(notifyOn, isNot('On'));
      expect(find.text(notifyOn), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
