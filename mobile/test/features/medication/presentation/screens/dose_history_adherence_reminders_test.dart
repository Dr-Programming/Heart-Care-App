import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide DoseLog, Medication;
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/adherence_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/adherence_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/dose_history_screen.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/reminder_bootstrap.dart';
import 'package:libu_care/features/medication/presentation/screens/reminder_settings_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';
import '../../helpers/fake_medication_repository.dart';

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

  testWidgets(
    'switching reminders off cancels the pending notifications rather than '
    'only writing the preference (I1)',
    (tester) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final RecordingScheduler scheduler = RecordingScheduler();
      final FakeMedicationRepository repository = FakeMedicationRepository(
        medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
      );
      final MedicationReminderBootstrap bootstrap = MedicationReminderBootstrap(
        scheduler: scheduler,
        notifications: MedicationNotifications(scheduler, db.preferencesDao),
        repository: repository,
      );
      // The app-start bootstrap has already armed this medication.
      await bootstrap.rescheduleAll();
      expect(scheduler.pendingPayloads, isNotEmpty);

      await pumpApp(
        tester,
        const ReminderSettingsScreen(),
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          medicationReminderBootstrapProvider.overrideWithValue(bootstrap),
          medicationListControllerProvider.overrideWith(
            () => _FakeMedicationListController(
              MedicationListState(
                todaysDoses: const <ScheduledDose>[],
                medications: <Medication>[
                  fakeMedication(clientRecordId: 'm1'),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        await db.preferencesDao.get(PreferenceKeys.notificationsEnabled),
        'false',
      );
      expect(scheduler.pendingPayloads, isEmpty);
    },
  );

  testWidgets('switching reminders back on re-arms them (I1)', (tester) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await db.preferencesDao.set(PreferenceKeys.notificationsEnabled, 'false');

    final RecordingScheduler scheduler = RecordingScheduler();
    final FakeMedicationRepository repository = FakeMedicationRepository(
      medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
    );

    await pumpApp(
      tester,
      const ReminderSettingsScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        medicationReminderBootstrapProvider.overrideWithValue(
          MedicationReminderBootstrap(
            scheduler: scheduler,
            notifications: MedicationNotifications(scheduler, db.preferencesDao),
            repository: repository,
          ),
        ),
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(
              todaysDoses: const <ScheduledDose>[],
              medications: <Medication>[fakeMedication(clientRecordId: 'm1')],
            ),
          ),
        ),
      ],
    );

    expect(scheduler.pendingPayloads, isEmpty);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // One scheduled time, main + follow-up.
    expect(scheduler.pendingPayloads, hasLength(2));
  });
}
