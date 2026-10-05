import '../../../../core/sync/history_window.dart';
import '../../../../core/db/app_database.dart' show SyncEntityType;
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_local_datasource.dart';
import '../datasources/activity_remote_datasource.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl({
    required this.local,
    required this.syncEnqueuer,
    this.remote,
    Future<bool> Function()? isOnline,
  }) : isOnline = isOnline ?? _offline;

  final ActivityLocalDataSource local;
  final SyncEnqueuer syncEnqueuer;
  final ActivityRemoteDataSource? remote;
  final Future<bool> Function() isOnline;

  static Future<bool> _offline() async => false;

  /// Brings back activities the server has and the phone doesn't.
  Future<void> restoreFromServer() async {
    final ActivityRemoteDataSource? source = remote;
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
        await local.insert(
          ActivityEntry(
            clientRecordId: clientRecordId,
            type: ActivityType.fromWire(data['type'] as String? ?? ''),
            durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
            intensity: Intensity.fromWire(data['intensity'] as String? ?? ''),
            measuredAt: measuredAt,
            steps: (data['steps'] as num?)?.toInt(),
            distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
            note: json['note'] as String?,
          ),
        );
      }
    }
  }

  @override
  Future<ActivityEntry> log({
    required ActivityType type,
    required int durationMinutes,
    required Intensity intensity,
    int? steps,
    double? distanceMeters,
    String? note,
    DateTime? measuredAt,
  }) async {
    final DateTime at = (measuredAt ?? DateTime.now()).toUtc();
    final ActivityEntry entry = ActivityEntry(
      clientRecordId: newClientRecordId(),
      type: type,
      durationMinutes: durationMinutes,
      intensity: intensity,
      measuredAt: at,
      steps: steps,
      distanceMeters: distanceMeters,
      note: note,
    );

    await local.insert(entry);
    await syncEnqueuer.enqueue(
      clientRecordId: entry.clientRecordId,
      entityType: SyncEntityType.activity,
      // The server rejects unknown keys and validates every key it gets, so
      // optional fields are left out rather than sent as null.
      payload: <String, dynamic>{
        'data': <String, dynamic>{
          'type': type.wire,
          'durationMinutes': durationMinutes,
          'intensity': intensity.wire,
          'steps': ?steps,
          'distanceMeters': ?distanceMeters,
        },
        'measuredAt': DateFormatter.toApiDateTime(at),
        'note': ?note,
      },
      recordedAt: at,
    );
    return entry;
  }

  @override
  Future<List<ActivityEntry>> history() => local.history();
}
