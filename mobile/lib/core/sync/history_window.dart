import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../utils/date_formatter.dart';

/// How many days of health records this phone keeps. Older records that have
/// reached the server are deleted here; the server keeps them all.
const int localHistoryDays = 30;

/// Downloaded first after a sign-in, so the app is usable quickly.
const int firstDownloadDays = 7;

/// A span of whole days, both ends included, as the API's `from` and `to`.
class DayRange {
  const DayRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  String get fromParam => DateFormatter.toApiDate(from);
  String get toParam => DateFormatter.toApiDate(to);

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DayRange($fromParam..$toParam)';
}

/// What to download after a sign-in, newest first: the last
/// [firstDownloadDays], then the rest of the [localHistoryDays].
List<DayRange> restoreRanges({DateTime? now}) {
  final DateTime today = DateFormatter.startOfDay(now ?? DateTime.now());
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);
  return <DayRange>[
    DayRange(daysAgo(firstDownloadDays - 1), today),
    DayRange(daysAgo(localHistoryDays - 1), daysAgo(firstDownloadDays)),
  ];
}

/// The first day kept on the phone; records from before it may be deleted.
DateTime oldestKeptDay({DateTime? now}) {
  final DateTime today = DateFormatter.startOfDay(now ?? DateTime.now());
  return DateTime(today.year, today.month, today.day - (localHistoryDays - 1));
}

const List<LocalSyncStatus> _notYetOnServer = <LocalSyncStatus>[
  LocalSyncStatus.pending,
  LocalSyncStatus.syncing,
  LocalSyncStatus.conflict,
];

extension HistoryPruning on AppDatabase {
  /// Records saved on this phone that the server has not accepted yet.
  Future<int> unsentRecordCount() async {
    final Expression<int> count = syncQueueEntries.id.count();
    final TypedResult row =
        await (selectOnly(syncQueueEntries)
              ..addColumns(<Expression<Object>>[count])
              ..where(
                syncQueueEntries.status.isIn(<String>[
                  for (final s in _notYetOnServer) s.name,
                ]),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Deletes health records from before [oldestKeptDay] that are on the
  /// server, with their finished sync entries. Anything not yet sent stays,
  /// however old. Medications themselves are kept: reminders need them.
  /// Returns how many records were removed.
  Future<int> pruneOldSyncedRecords({DateTime? now}) => transaction(() async {
    final DateTime cutoff = oldestKeptDay(now: now);
    final String cutoffDate = DateFormatter.toApiDate(cutoff);

    final List<String> unsent =
        await (selectOnly(syncQueueEntries)
              ..addColumns(<Expression<Object>>[
                syncQueueEntries.clientRecordId,
              ])
              ..where(
                syncQueueEntries.status.isIn(<String>[
                  for (final s in _notYetOnServer) s.name,
                ]),
              ))
            .map((TypedResult r) => r.read(syncQueueEntries.clientRecordId)!)
            .get();

    int removed = 0;
    removed +=
        await (delete(vitalsLogs)..where(
              ($VitalsLogsTable t) =>
                  t.measuredAt.isSmallerThanValue(cutoff) &
                  t.clientRecordId.isNotIn(unsent),
            ))
            .go();
    removed +=
        await (delete(symptomLogs)..where(
              ($SymptomLogsTable t) =>
                  t.measuredAt.isSmallerThanValue(cutoff) &
                  t.clientRecordId.isNotIn(unsent),
            ))
            .go();
    removed +=
        await (delete(activityLogs)..where(
              ($ActivityLogsTable t) =>
                  t.measuredAt.isSmallerThanValue(cutoff) &
                  t.clientRecordId.isNotIn(unsent),
            ))
            .go();
    removed +=
        await (delete(doseLogs)..where(
              ($DoseLogsTable t) =>
                  t.scheduledDate.isSmallerThanValue(cutoffDate) &
                  t.clientRecordId.isNotIn(unsent),
            ))
            .go();

    // Finished queue entries for old records are only history now. Rejected
    // ones stay until the patient has seen and dismissed them.
    await (delete(syncQueueEntries)..where(
          ($SyncQueueEntriesTable t) =>
              t.recordedAt.isSmallerThanValue(cutoff) &
              t.status.equalsValue(LocalSyncStatus.synced),
        ))
        .go();
    return removed;
  });
}
