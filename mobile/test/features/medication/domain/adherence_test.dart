import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/schedule.dart';

Medication _daily(String id, DateTime createdAt, {bool active = true, DateTime? updatedAt}) {
  return Medication(
    clientRecordId: id,
    serverId: null,
    name: 'Med $id',
    doseMg: 10,
    frequency: MedicationFrequency.onceDaily,
    scheduleTimes: const <String>['08:00'],
    active: active,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
  );
}

DoseLog _log(String medicationId, String date, DoseStatus status) {
  return DoseLog(
    clientRecordId: '$medicationId-$date',
    serverId: null,
    medicationClientRecordId: medicationId,
    medicationServerId: null,
    status: status,
    scheduledDate: date,
    scheduledTime: '08:00',
    loggedAt: DateTime.parse('${date}T08:05:00Z'),
    note: null,
  );
}

void main() {
  test('3 taken of 4 due is 75%', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: <DoseLog>[
        _log('m1', '2026-08-19', DoseStatus.taken),
        _log('m1', '2026-08-20', DoseStatus.taken),
        _log('m1', '2026-08-21', DoseStatus.taken),
        // 2026-08-22 due, never logged -> counts toward due, not taken
      ],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 22, 12),
      windowDays: 7,
    );

    expect(a.due, 4);
    expect(a.taken, 3);
    expect(a.percentage, closeTo(0.75, 0.0001));
  });

  test('SKIPPED is excluded from both taken and due', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: <DoseLog>[
        _log('m1', '2026-08-19', DoseStatus.taken),
        _log('m1', '2026-08-20', DoseStatus.skipped),
      ],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 20, 23),
      windowDays: 7,
    );

    expect(a.due, 1);
    expect(a.taken, 1);
    expect(a.skipped, 1);
    expect(a.percentage, 1.0);
  });

  test('doses later today are not counted as due', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 25),
      now: DateTime(2026, 8, 25, 6), // before today's 08:00 slot
      windowDays: 7,
    );

    expect(a.due, 0);
    expect(a.hasData, isFalse);
  });

  test('a window with zero due doses reports no data, not 0% or a crash', () {
    final Adherence a = computeAdherence(
      medications: const <Medication>[],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 25, 12),
      windowDays: 7,
    );

    expect(a.hasData, isFalse);
    expect(a.percentage, isNull);
  });

  test('a 7-day window includes exactly 7 calendar days up to today', () {
    final Medication med = _daily('m1', DateTime(2026, 1, 1));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 19), // 19,20,21,22,23,24,25 = 7 days
      now: DateTime(2026, 8, 25, 23),
      windowDays: 7,
    );
    expect(a.due, 7);
  });
}
