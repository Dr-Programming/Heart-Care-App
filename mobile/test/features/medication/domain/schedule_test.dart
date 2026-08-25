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
