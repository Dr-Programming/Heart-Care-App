import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication;
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/reminder_bootstrap.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/home/todays_doses_card.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';
import '../../helpers/fake_medication_repository.dart';

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;
  @override
  Future<MedicationListState> build() async => _state;
}

/// The reminder bootstrap this card fires at app start reaches the real
/// notification plugin and the real on-device database, neither of which
/// exists under `flutter test`. Every card test that is not *about* the
/// bootstrap replaces it with a no-op.
Override get _noBootstrap =>
    medicationRemindersStartupProvider.overrideWith((Ref _) {});

void main() {
  setUpWidgetTests();

  testWidgets('shows the empty-today text when nothing is due', (tester) async {
    await pumpApp(
      tester,
      Material(child: Builder(builder: todaysDosesHomeCard().builder)),
      overrides: <Override>[
        _noBootstrap,
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
        _noBootstrap,
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

  testWidgets(
    'mounting the Home card boots the reminder scheduler and reschedules '
    'every active medication (C2)',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final RecordingScheduler scheduler = RecordingScheduler();
      final FakeMedicationRepository repository = FakeMedicationRepository(
        medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
      );

      await pumpApp(
        tester,
        Material(child: Builder(builder: todaysDosesHomeCard().builder)),
        overrides: <Override>[
          medicationReminderBootstrapProvider.overrideWithValue(
            MedicationReminderBootstrap(
              scheduler: scheduler,
              notifications: MedicationNotifications(
                scheduler,
                db.preferencesDao,
              ),
              repository: repository,
            ),
          ),
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              const MedicationListState(
                todaysDoses: <ScheduledDose>[],
                medications: <Medication>[],
              ),
            ),
          ),
        ],
      );

      // `NotificationScheduler.init()` had no production caller at all before
      // this fix, so timezone setup, plugin init and the Android 13+
      // POST_NOTIFICATIONS request never ran.
      expect(scheduler.initCalls, 1);
      // ...and nothing rescheduled on app start, which Android needs after a
      // reboot or force-stop (Decision 4). One time slot, main + follow-up.
      expect(scheduler.pendingPayloads, hasLength(2));
    },
  );
}
