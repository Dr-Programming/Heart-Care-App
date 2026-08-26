import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/adherence_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/adherence_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/dose_history_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/reminder_settings_screen.dart';

import '../../../../helpers/pump_app.dart';

class _FakeDoseHistoryController extends DoseHistoryController {
  _FakeDoseHistoryController(this._logs);
  final List<DoseLog> _logs;
  @override
  Future<List<DoseLog>> build() async => _logs;
}

class _FakeAdherenceController extends AdherenceController {
  _FakeAdherenceController(this._state);
  final AdherenceState _state;
  @override
  Future<AdherenceState> build() async => _state;
}

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;
  @override
  Future<MedicationListState> build() async => _state;
}

void main() {
  setUpWidgetTests();

  testWidgets('DoseHistoryScreen shows an empty state with no logs', (tester) async {
    await pumpApp(
      tester,
      const DoseHistoryScreen(),
      overrides: <Override>[
        doseHistoryControllerProvider.overrideWith(() => _FakeDoseHistoryController(const <DoseLog>[])),
      ],
    );
    expect(find.text('meds.history.emptyTitle'.tr()), findsOneWidget);
  });

  testWidgets('AdherenceScreen shows honest no-data text for a zero-due window', (tester) async {
    await pumpApp(
      tester,
      const AdherenceScreen(),
      overrides: <Override>[
        adherenceControllerProvider.overrideWith(
          () => _FakeAdherenceController(
            const AdherenceState(
              overall7: Adherence(taken: 0, due: 0, skipped: 0, windowDays: 7),
              overall30: Adherence(taken: 0, due: 0, skipped: 0, windowDays: 30),
              perMedication7: <String, Adherence>{},
              perMedication30: <String, Adherence>{},
            ),
          ),
        ),
      ],
    );
    expect(find.text('meds.adherence.noData'.tr()), findsWidgets);
  });

  testWidgets('ReminderSettingsScreen lists each medication\'s times', (tester) async {
    final Medication med = Medication(
      clientRecordId: 'm1', serverId: null, name: 'Aspirin', doseMg: 75,
      frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
      active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
    );
    await pumpApp(
      tester,
      const ReminderSettingsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(todaysDoses: const <ScheduledDose>[], medications: <Medication>[med]),
          ),
        ),
      ],
    );
    expect(find.textContaining('Aspirin'), findsOneWidget);
  });
}
