import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
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
}
