import 'dart:ui' show Size;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medications_screen.dart';

import '../../../../helpers/pump_app.dart';

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

  testWidgets('shows today\'s doses and the medication list when loaded', (tester) async {
    // `StatusSelector`'s chip labels also fall back to their literal (long)
    // translation keys under the same unpopulated `meds` namespace, which
    // overflows `DoseRow`'s Row at the default 800x600 test surface. Widen
    // the surface so the fallback strings fit — with the real short labels
    // ("Taken"/"Missed"/"Skipped") this row fits comfortably on any real
    // device width, so this is purely a test-environment accommodation for
    // the not-yet-populated namespace, not a production layout fix.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
}
