import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/schedule.dart';

Medication _med({
  required String id,
  required List<String> times,
  bool active = true,
  DateTime? createdAt,
  DateTime? updatedAt,
  MedicationFrequency frequency = MedicationFrequency.onceDaily,
}) {
  final DateTime created = createdAt ?? DateTime(2026, 1, 1);
  return Medication(
    clientRecordId: id,
    serverId: null,
    name: 'Med $id',
    doseMg: 10,
    frequency: frequency,
    scheduleTimes: times,
    active: active,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  group('isActiveOn', () {
    test('a medication is not due before it existed', () {
      final Medication med = _med(
        id: 'm1',
        times: <String>['08:00'],
        createdAt: DateTime(2026, 8, 10),
      );
      expect(isActiveOn(med, DateTime(2026, 8, 9)), isFalse);
      expect(isActiveOn(med, DateTime(2026, 8, 10)), isTrue);
    });

    test('a deactivated medication is not due after it was deactivated', () {
      final Medication med = _med(
        id: 'm1',
        times: <String>['08:00'],
        createdAt: DateTime(2026, 8, 1),
        active: false,
        updatedAt: DateTime(2026, 8, 15),
      );
      expect(isActiveOn(med, DateTime(2026, 8, 14)), isTrue);
      expect(isActiveOn(med, DateTime(2026, 8, 16)), isFalse);
    });

    test(
      'a reactivated medication incorrectly treats the inactive gap as active '
      '(known limitation: multi-transition handling requires schema change)',
      () {
        // This test documents a real gap in isActiveOn that cannot be fixed
        // without an activation-history column in the schema (owned by the
        // foundation, out of scope for this slice). The scenario:
        // 1. Medication created on 2026-08-01
        // 2. Deactivated (active: false, updatedAt: 2026-08-05) on day 5
        // 3. Reactivated (active: true, updatedAt: 2026-08-15) on day 15
        // isActiveOn should return:
        //   - true for 2026-08-01 (creation day)
        //   - true for 2026-08-04 (before deactivation)
        //   - false for 2026-08-06 (after deactivation, before reactivation)
        //   - true for 2026-08-16 (after reactivation)
        // However, due to the schema limitation, isActiveOn only checks
        // active/updatedAt when active=false. After reactivation (active=true),
        // it consults only createdAt and never sees the deactivation at all,
        // so days 2026-08-06 through 2026-08-10 are incorrectly returned as
        // true. This causes computeAdherence to overcount "due" for those days.
        final Medication medReactivated = _med(
          id: 'm1',
          times: <String>['08:00'],
          createdAt: DateTime(2026, 8, 1),
          active: true,
          updatedAt: DateTime(2026, 8, 15), // reactivation date
        );

        // The bug: day 6 should be false (was deactivated on day 5),
        // but isActiveOn returns true because active=true and createdAt
        // is before day 6. updatedAt (day 15) is not consulted.
        expect(
          isActiveOn(medReactivated, DateTime(2026, 8, 6)),
          isTrue, // BUG: should be false, but implementation only checks createdAt
        );
        expect(
          isActiveOn(medReactivated, DateTime(2026, 8, 10)),
          isTrue, // BUG: should be false (in the inactive gap)
        );

        // After reactivation, correctly reports true.
        expect(isActiveOn(medReactivated, DateTime(2026, 8, 16)), isTrue);
      },
    );
  });

  group('scheduledDosesFor', () {
    test('yields one slot per scheduled time, whatever the frequency', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 23);
      final List<ScheduledDose> once = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm1', times: <String>['08:00'], frequency: MedicationFrequency.onceDaily),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );
      final List<ScheduledDose> bid = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm2', times: <String>['08:00', '20:00'], frequency: MedicationFrequency.bid),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );
      final List<ScheduledDose> custom = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm3', times: <String>['06:00', '12:00', '18:00', '22:00'], frequency: MedicationFrequency.custom),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      expect(once, hasLength(1));
      expect(bid, hasLength(2));
      expect(custom, hasLength(4));
    });

    test('an unlogged past-due slot is overdue; an unlogged future slot is pending', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 12);
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm1', times: <String>['08:00', '20:00']),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      final ScheduledDose morning = doses.firstWhere((ScheduledDose d) => d.scheduledTime == '08:00');
      final ScheduledDose evening = doses.firstWhere((ScheduledDose d) => d.scheduledTime == '20:00');
      expect(morning.status, ScheduledDoseStatus.overdue);
      expect(evening.status, ScheduledDoseStatus.pending);
    });

    test('a slot with a matching log is logged and carries the log', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DoseLog log = DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: DateTime.utc(2026, 8, 25, 8, 2),
        note: null,
      );
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['08:00'])],
        logsForDate: <DoseLog>[log],
        date: date,
        now: DateTime(2026, 8, 25, 12),
      );

      expect(doses.single.status, ScheduledDoseStatus.logged);
      expect(doses.single.doseLog, log);
    });

    test('a late-evening slot stays on its own calendar day, not shifted by UTC', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 23, 45);
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['23:30'])],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      expect(doses.single.scheduledDate, '2026-08-25');
      expect(doses.single.status, ScheduledDoseStatus.overdue);
    });

    test('an inactive medication contributes no slots', () {
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['08:00'], active: false)],
        logsForDate: const <DoseLog>[],
        date: DateTime(2026, 8, 25),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(doses, isEmpty);
    });
  });
}
