import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../caregiver/caregiver_contact.dart';
import '../clinical/alert_evaluator.dart';
import '../db/app_database.dart';
import '../providers/core_providers.dart';
import 'clinic_contact.dart';

/// How many urgent-or-worse readings in [urgentPatternWindow] mean the
/// patient should call their clinic.
const int urgentPatternThreshold = 3;
const Duration urgentPatternWindow = Duration(days: 7);

/// Set when the patient dismisses the "call your clinic" reminder; it comes
/// back with the next urgent reading after that.
const String clinicAlertDismissedKey = 'clinic_alert_dismissed_at';

/// The urgent-or-worse readings (vitals and check-ins) of the last
/// [urgentPatternWindow].
class UrgentPattern {
  const UrgentPattern({required this.count, this.latest, this.dismissedAt});

  static const UrgentPattern none = UrgentPattern(count: 0);

  final int count;
  final DateTime? latest;
  final DateTime? dismissedAt;

  bool get reached => count >= urgentPatternThreshold;

  /// Reached, and not dismissed since the latest urgent reading.
  bool get shouldRemind =>
      reached &&
      latest != null &&
      (dismissedAt == null || latest!.isAfter(dismissedAt!));
}

bool _isUrgent(Severity severity) => severity.index >= Severity.urgent.index;

Future<UrgentPattern> readUrgentPattern(AppDatabase db, {DateTime? now}) async {
  final DateTime since = (now ?? DateTime.now()).subtract(urgentPatternWindow);
  final List<DateTime> times = <DateTime>[];

  final List<VitalsLog> vitals =
      await (db.select(db.vitalsLogs)..where(
            ($VitalsLogsTable t) => t.measuredAt.isBiggerOrEqualValue(since),
          ))
          .get();
  for (final VitalsLog row in vitals) {
    final Object? values = jsonDecode(row.valuesJson);
    if (values is! Map) continue;
    final Severity severity = severityForVital(
      type: row.type,
      values: <String, num?>{
        for (final MapEntry<dynamic, dynamic> e in values.entries)
          '${e.key}': e.value is num ? e.value as num : null,
      },
      bmi: row.bmi,
    );
    if (_isUrgent(severity)) times.add(row.measuredAt);
  }

  final List<SymptomLog> checkIns =
      await (db.select(db.symptomLogs)..where(
            ($SymptomLogsTable t) => t.measuredAt.isBiggerOrEqualValue(since),
          ))
          .get();
  for (final SymptomLog row in checkIns) {
    if (_isUrgent(Severity.fromWire(row.overallSeverity))) {
      times.add(row.measuredAt);
    }
  }

  final String? dismissed = await db.preferencesDao.get(
    clinicAlertDismissedKey,
  );
  times.sort();
  return UrgentPattern(
    count: times.length,
    latest: times.isEmpty ? null : times.last,
    dismissedAt: dismissed == null ? null : DateTime.tryParse(dismissed),
  );
}

Future<void> dismissClinicReminder(AppDatabase db) => db.preferencesDao.set(
  clinicAlertDismissedKey,
  DateTime.now().toIso8601String(),
);

/// Recounted whenever a reading, check-in or preference changes.
final StreamProvider<UrgentPattern> urgentPatternProvider =
    StreamProvider<UrgentPattern>((Ref ref) {
      final AppDatabase db = ref.watch(appDatabaseProvider);
      return db
          .customSelect(
            'SELECT 1',
            readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
              db.vitalsLogs,
              db.symptomLogs,
              db.preferences,
            },
          )
          .watch()
          .asyncMap((_) => readUrgentPattern(db));
    });

/// The saved clinic, kept current as it is edited anywhere in the app.
final StreamProvider<ClinicContact?> clinicContactProvider =
    StreamProvider<ClinicContact?>((Ref ref) {
      final AppDatabase db = ref.watch(appDatabaseProvider);
      return (db.select(db.preferences)..where(
            ($PreferencesTable t) =>
                t.key.equals(ClinicContactStore.storageKey),
          ))
          .watchSingleOrNull()
          .map((Preference? row) => ContactStore.parse(row?.value));
    });
