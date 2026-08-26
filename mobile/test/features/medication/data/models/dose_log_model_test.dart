import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/models/dose_log_model.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';

void main() {
  final Map<String, dynamic> wireJson = <String, dynamic>{
    'id': 'dose-server-1',
    'medicationId': 'med-server-1',
    'scheduledDate': '2026-07-16',
    'scheduledTime': '08:00',
    'status': 'TAKEN',
    'loggedAt': '2026-07-16T05:05:00Z',
    'note': 'taken with breakfast',
    'clientRecordId': 'dose-client-1',
    'createdAt': '2026-07-16T05:05:02Z',
  };

  test('fromJson parses the documented response shape', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    expect(model.id, 'dose-server-1');
    expect(model.medicationId, 'med-server-1');
    expect(model.status, 'TAKEN');
    expect(model.note, 'taken with breakfast');
  });

  test('toEntity requires the caller to supply the client-side medication link', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    final DoseLog entity = model.toEntity(medicationClientRecordId: 'med-client-1');
    expect(entity.medicationClientRecordId, 'med-client-1');
    expect(entity.medicationServerId, 'med-server-1');
    expect(entity.status, DoseStatus.taken);
    expect(entity.scheduledDate, '2026-07-16');
  });

  test('toCompanion carries the client id as primary key', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    final companion = model.toCompanion(medicationClientRecordId: 'med-client-1');
    expect(companion.clientRecordId.value, 'dose-client-1');
    expect(companion.medicationClientRecordId.value, 'med-client-1');
    expect(companion.status.value, 'TAKEN');
  });
}
