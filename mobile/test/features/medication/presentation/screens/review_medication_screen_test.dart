import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
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
      const ReviewMedicationScreen(),
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
      const ReviewMedicationScreen(),
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
      const ReviewMedicationScreen(),
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
      const ReviewMedicationScreen(),
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
}
