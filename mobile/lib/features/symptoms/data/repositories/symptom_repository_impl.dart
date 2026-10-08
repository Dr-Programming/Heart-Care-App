import '../../../../core/sync/history_window.dart';
import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../domain/repositories/symptom_repository.dart';
import '../datasources/symptom_local_datasource.dart';
import '../datasources/symptom_remote_datasource.dart';

class SymptomRepositoryImpl implements SymptomRepository {
  SymptomRepositoryImpl({
    required this.local,
    required this.syncEnqueuer,
    this.remote,
    Future<bool> Function()? isOnline,
  }) : isOnline = isOnline ?? _offline;

  final SymptomLocalDataSource local;
  final SyncEnqueuer syncEnqueuer;
  final SymptomRemoteDataSource? remote;
  final Future<bool> Function() isOnline;

  static Future<bool> _offline() async => false;

  /// Brings back check-ins the server has and the phone doesn't. The
  /// assessment is worked out again here with the same rules.
  Future<void> restoreFromServer() async {
    final SymptomRemoteDataSource? source = remote;
    if (source == null || !await isOnline()) return;
    // Newest week first, then the rest of the month kept on the phone.
    for (final DayRange range in restoreRanges()) {
      for (final Map<String, dynamic> json in await source.history(
        from: range.fromParam,
        to: range.toParam,
      )) {
        final String? clientRecordId =
            json['clientRecordId'] as String? ?? json['id'] as String?;
        final Object? data = json['data'];
        final DateTime? measuredAt = DateTime.tryParse(
          json['measuredAt'] as String? ?? '',
        );
        if (clientRecordId == null || data is! Map || measuredAt == null) {
          continue;
        }
        if (await local.exists(clientRecordId)) continue;
        final Map<String, dynamic> values = data.cast<String, dynamic>();
        final SymptomAssessment assessment = assessSymptoms(values);
        await local.insert(
          SymptomCheckIn(
            clientRecordId: clientRecordId,
            data: values,
            overall: assessment.overall,
            perSymptom: assessment.symptoms,
            measuredAt: measuredAt,
            note: json['note'] as String?,
          ),
        );
      }
    }
  }

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
