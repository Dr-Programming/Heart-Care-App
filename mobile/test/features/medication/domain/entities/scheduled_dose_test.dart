import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';

void main() {
  test('a ScheduledDose with no doseLog is not logged', () {
    const ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending,
      doseLog: null,
    );

    expect(dose.status, ScheduledDoseStatus.pending);
    expect(dose.doseLog, isNull);
  });

  test('a ScheduledDose carries its matched doseLog when logged', () {
    final DoseLog log = DoseLog(
      clientRecordId: 'd1',
      serverId: null,
      medicationClientRecordId: 'm1',
      medicationServerId: null,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      loggedAt: DateTime.utc(2026, 8, 25, 8),
      note: null,
    );
    final ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.logged,
      doseLog: log,
    );

    expect(dose.status, ScheduledDoseStatus.logged);
    expect(dose.doseLog!.status, DoseStatus.taken);
  });
}
