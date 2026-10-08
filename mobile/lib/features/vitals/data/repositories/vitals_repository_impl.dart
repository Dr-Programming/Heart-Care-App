import '../../../../core/sync/history_window.dart';
import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/bmi.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../datasources/vitals_local_datasource.dart';
import '../datasources/vitals_remote_datasource.dart';
import '../models/vital_model.dart';

class VitalsRepositoryImpl implements VitalsRepository {
  VitalsRepositoryImpl({
    required this.local,
    required this.syncEnqueuer,
    this.remote,
    Future<bool> Function()? isOnline,
  }) : isOnline = isOnline ?? _offline;

  final VitalsLocalDataSource local;
  final SyncEnqueuer syncEnqueuer;
  final VitalsRemoteDataSource? remote;
  final Future<bool> Function() isOnline;

  static Future<bool> _offline() async => false;

  /// Brings back readings the server has and the phone doesn't (a new phone,
  /// or another patient used this one). Never overwrites a local reading.
  Future<void> restoreFromServer() async {
    final VitalsRemoteDataSource? source = remote;
    if (source == null || !await isOnline()) return;
    // Newest week first, then the rest of the month kept on the phone.
    for (final DayRange range in restoreRanges()) {
      for (final VitalModel server in await source.history(
        from: range.fromParam,
        to: range.toParam,
      )) {
        final String clientRecordId = server.clientRecordId.isNotEmpty
            ? server.clientRecordId
            : (server.serverId ?? '');
        if (clientRecordId.isEmpty || await local.exists(clientRecordId)) {
          continue;
        }
        await local.insert(server.copyWith(clientRecordId: clientRecordId));
      }
    }
  }

  @override
  Future<VitalReading> logReading({
    required VitalType type,
    required Map<String, double> values,
    DateTime? measuredAt,
    String? note,
  }) async {
    final DateTime effectiveMeasuredAt = (measuredAt ?? DateTime.now()).toUtc();

    double? bmi;
    if (type == VitalType.weight) {
      final double? heightCm = await local.latestHeightCm();
      bmi = calculateBmi(weightKg: values['weight']!, heightCm: heightCm);
    }

    final Map<String, num?> flagCheckValues = <String, num?>{
      ...values,
      if (bmi != null) 'bmi': bmi,
    };
    final bool flagged = isVitalFlagged(flagCheckValues);

    final VitalReading entity = VitalReading(
      clientRecordId: newClientRecordId(),
      serverId: null,
      type: type,
      values: values,
      flagged: flagged,
      bmi: bmi,
      measuredAt: effectiveMeasuredAt,
      note: note,
    );

    await local.insert(VitalModel.fromEntity(entity));

    await syncEnqueuer.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.vital,
      payload: <String, dynamic>{
        'type': type.wire,
        'values': values,
        'measuredAt': DateFormatter.toApiDateTime(effectiveMeasuredAt),
        if (note != null) 'note': note,
      },
      recordedAt: effectiveMeasuredAt,
    );

    return entity;
  }

  @override
  Future<List<VitalReading>> history({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => local.history(type: type, from: from, to: to);

  @override
  Future<Map<VitalType, VitalReading?>> latestByType() => local.latestByType();

  @override
  Future<double?> latestHeightCm() => local.latestHeightCm();

  @override
  Future<VitalGoals?> latestGoals() => local.latestGoals();
}
