import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';

import '../../../../helpers/pump_app.dart';

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
}
