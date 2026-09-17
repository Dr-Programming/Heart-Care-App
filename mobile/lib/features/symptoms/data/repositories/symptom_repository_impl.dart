import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../datasources/symptom_local_datasource.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  SymptomRepositoryImpl({required this.local, required this.syncEnqueuer});

  final SymptomLocalDataSource local;
  final SyncEnqueuer syncEnqueuer;

  @override
  Future<SymptomCheckIn> submit({
    required Map<String, dynamic> data,
    String? note,
    DateTime? measuredAt,
  }) async {
    final DateTime effectiveMeasuredAt = (measuredAt ?? DateTime.now()).toUtc();
    final SymptomAssessment assessment = assessSymptoms(data);

    final SymptomCheckIn entity = SymptomCheckIn(
      clientRecordId: newClientRecordId(),
      data: data,
      overall: assessment.overall,
      perSymptom: assessment.symptoms,
      measuredAt: effectiveMeasuredAt,
      note: note,
    );

    await local.insert(entity);

    await syncEnqueuer.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.symptom,
      payload: <String, dynamic>{
        'data': data,
        'measuredAt': DateFormatter.toApiDateTime(effectiveMeasuredAt),
        if (note != null) 'note': note,
      },
      recordedAt: effectiveMeasuredAt,
    );

    return entity;
  }

  @override
  Future<SymptomCheckIn?> latestToday() => local.latestToday();

  @override
  Future<List<SymptomCheckIn>> history() => local.history();
}
