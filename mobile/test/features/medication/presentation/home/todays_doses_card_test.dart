import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/home/todays_doses_card.dart';

import '../../../../helpers/pump_app.dart';

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;
  @override
  Future<MedicationListState> build() async => _state;
}

void main() {
  setUpWidgetTests();

  testWidgets('shows the empty-today text when nothing is due', (tester) async {
    await pumpApp(
      tester,
      Material(child: Builder(builder: todaysDosesHomeCard().builder)),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
          ),
        ),
      ],
    );
    expect(find.text('meds.todayEmpty'.tr()), findsOneWidget);
  });

  testWidgets('shows a DoseRow per due dose, up to three', (tester) async {
    const List<ScheduledDose> doses = <ScheduledDose>[
      ScheduledDose(medicationClientRecordId: 'm1', medicationName: 'A', doseMg: 1, scheduledDate: '2026-08-25', scheduledTime: '08:00', status: ScheduledDoseStatus.pending, doseLog: null),
      ScheduledDose(medicationClientRecordId: 'm2', medicationName: 'B', doseMg: 1, scheduledDate: '2026-08-25', scheduledTime: '09:00', status: ScheduledDoseStatus.pending, doseLog: null),
    ];
    await pumpApp(
      tester,
      Material(child: Builder(builder: todaysDosesHomeCard().builder)),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: doses, medications: <Medication>[]),
          ),
        ),
      ],
    );
    expect(find.textContaining('A'), findsWidgets);
    expect(find.textContaining('B'), findsWidgets);
  });
}
