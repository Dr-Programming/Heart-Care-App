import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/datasources/medication_local_datasource.dart';
import 'package:libu_care/features/medication/data/models/dose_log_model.dart';
import 'package:libu_care/features/medication/data/models/medication_model.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MedicationLocalDataSource datasource;

  setUp(() {
    db = testDatabase();
    datasource = MedicationLocalDataSource(db);
  });

  tearDown(() => db.close());

  MedicationModel medication({
    String clientId = 'm1',
    bool active = true,
    List<String> times = const <String>['08:00', '20:00'],
  }) {
    final DateTime now = DateTime.utc(2026, 8, 25);
    return MedicationModel(
      id: null,
      name: 'Atorvastatin',
      doseMg: 20,
      frequency: 'ONCE_DAILY',
      scheduleTimes: times,
      active: active,
      clientRecordId: clientId,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('round-trips a medication with several scheduled times', () async {
    await datasource.upsertMedication(medication());

    final found = await datasource.findMedication('m1');

    expect(found, isNotNull);
    expect(found!.name, 'Atorvastatin');
    expect(found.scheduleTimes, <String>['08:00', '20:00']);
  });

  test('deactivating keeps the row and its dose logs', () async {
    await datasource.upsertMedication(medication());
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        clientRecordId: 'd1',
        loggedAt: DateTime.utc(2026, 8, 25, 8, 5),
      ),
      medicationClientRecordId: 'm1',
    );

    await datasource.upsertMedication(medication(active: false));

    final found = await datasource.findMedication('m1');
    final logs = await datasource.doseLogsInRange(medicationClientRecordId: 'm1');
    expect(found!.active, isFalse);
    expect(logs, hasLength(1));
  });

  test('activeMedications excludes deactivated rows', () async {
    await datasource.upsertMedication(medication(clientId: 'm1'));
    await datasource.upsertMedication(medication(clientId: 'm2', active: false));

    final active = await datasource.activeMedications();

    expect(active.map((m) => m.clientRecordId), <String>['m1']);
  });

  test('allMedications(includeInactive: true) returns both', () async {
    await datasource.upsertMedication(medication(clientId: 'm1'));
    await datasource.upsertMedication(medication(clientId: 'm2', active: false));

    final all = await datasource.allMedications(includeInactive: true);

    expect(all, hasLength(2));
  });

  test('setServerId caches the resolved server id locally', () async {
    await datasource.upsertMedication(medication());
    await datasource.setServerId('m1', 'srv-1');

    final found = await datasource.findMedication('m1');

    expect(found!.serverId, 'srv-1');
  });

  test('doseLogsForDate returns only that day\'s logs', () async {
    await datasource.upsertMedication(medication());
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        clientRecordId: 'd1',
        loggedAt: DateTime.utc(2026, 8, 25, 8),
      ),
      medicationClientRecordId: 'm1',
    );
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-24',
        scheduledTime: '08:00',
        clientRecordId: 'd2',
        loggedAt: DateTime.utc(2026, 8, 24, 8),
      ),
      medicationClientRecordId: 'm1',
    );

    final logs = await datasource.doseLogsForDate('2026-08-25');

    expect(logs, hasLength(1));
    expect(logs.single.clientRecordId, 'd1');
  });
}
