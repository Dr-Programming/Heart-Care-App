import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';

void main() {
  group('DoseStatus', () {
    test('wire values match the backend exactly', () {
      expect(DoseStatus.taken.wire, 'TAKEN');
      expect(DoseStatus.missed.wire, 'MISSED');
      expect(DoseStatus.skipped.wire, 'SKIPPED');
    });

    test('fromWire round-trips every value', () {
      for (final DoseStatus s in DoseStatus.values) {
        expect(DoseStatus.fromWire(s.wire), s);
      }
    });
  });

  group('DoseLog', () {
    test('holds every field passed to its constructor', () {
      final DateTime loggedAt = DateTime.utc(2026, 8, 25, 8, 5);
      final DoseLog log = DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: loggedAt,
        note: 'with breakfast',
      );

      expect(log.medicationClientRecordId, 'm1');
      expect(log.status, DoseStatus.taken);
      expect(log.scheduledDate, '2026-08-25');
      expect(log.scheduledTime, '08:00');
      expect(log.loggedAt, loggedAt);
      expect(log.note, 'with breakfast');
    });
  });
}
