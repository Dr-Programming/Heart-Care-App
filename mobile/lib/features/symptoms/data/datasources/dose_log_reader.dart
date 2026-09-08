import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/date_formatter.dart';

/// Reads `DoseLogs` directly for the missed-dose half of the cross-signal
/// (FR-DEC-003).
///
/// `DoseLogs` belongs to nobody — it is declared once in `core/db` for
/// every feature that needs it. This is a direct table query, not an
/// import from `features/medication/`, which this slice must never touch
/// (M5 spec §7).
class DoseLogReader {
  const DoseLogReader(this._db);

  final AppDatabase _db;

  /// True when any dose scheduled for [date] (default today) was logged
  /// `MISSED`.
  ///
  /// No dose rows at all — M3 not yet landed, or nothing was due — means
  /// false, not an error or a spinner; `adherenceCrossSignal` already
  /// treats that as "no missed dose" (design decision 4).
  Future<bool> hasMissedDose({DateTime? date}) async {
    final String scheduledDate = DateFormatter.toApiDate(
      date ?? DateTime.now(),
    );
    final DoseLog? row =
        await (_db.select(_db.doseLogs)
              ..where(
                ($DoseLogsTable t) =>
                    t.scheduledDate.equals(scheduledDate) &
                    t.status.equals('MISSED'),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
}
