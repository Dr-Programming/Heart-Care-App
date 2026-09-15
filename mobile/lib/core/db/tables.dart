import 'package:drift/drift.dart';

class CachedUsers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get preferredLanguage => text()();
  TextColumn get role => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

abstract final class PreferenceKeys {
  static const String language = 'language';
  static const String languageChosen = 'language_chosen';

  static const String notificationsEnabled = 'notifications_enabled';
  static const String symptomPromptTime = 'symptom_prompt_time';

  static const String lastSyncAt = 'last_sync_at';
}

class PatientProfiles extends Table {
  TextColumn get userId => text()();

  IntColumn get birthYear => integer().nullable()();
  TextColumn get preferredLanguage => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get chdStage => text().nullable()();
  TextColumn get diseaseHistory => text().nullable()();

  TextColumn get comorbiditiesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get managementPlan => text().nullable()();

  TextColumn get goalsJson => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{userId};
}

class Medications extends Table {
  TextColumn get clientRecordId => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text().withLength(max: 255)();
  RealColumn get doseMg => real()();

  TextColumn get frequency => text()();

  TextColumn get scheduleTimesJson => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clientRecordId};
}

class DoseLogs extends Table {
  TextColumn get clientRecordId => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get medicationClientRecordId => text()();
  TextColumn get medicationServerId => text().nullable()();

  TextColumn get status => text()();

  TextColumn get scheduledDate => text()();

  TextColumn get scheduledTime => text().nullable()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get note => text().withLength(max: 500).nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clientRecordId};
}

class VitalsLogs extends Table {
  TextColumn get clientRecordId => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get type => text()();

  TextColumn get valuesJson => text()();

  BoolColumn get flagged => boolean().nullable()();

  RealColumn get bmi => real().nullable()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get note => text().withLength(max: 500).nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clientRecordId};
}

class SymptomLogs extends Table {
  TextColumn get clientRecordId => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get dataJson => text()();

  TextColumn get assessmentJson => text().nullable()();

  TextColumn get overallSeverity => text().nullable()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get note => text().withLength(max: 500).nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clientRecordId};
}

class ActivityLogs extends Table {
  TextColumn get clientRecordId => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get type => text()();
  IntColumn get durationMinutes => integer()();

  TextColumn get intensity => text()();
  IntColumn get steps => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  DateTimeColumn get measuredAt => dateTime()();
  TextColumn get note => text().withLength(max: 500).nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clientRecordId};
}

class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get clientRecordId => text()();
  TextColumn get entityType => text()();

  TextColumn get payloadJson => text()();
  TextColumn get status => textEnum<LocalSyncStatus>()();

  TextColumn get serverId => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get createdLocallyAt => dateTime()();

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (entity_type, client_record_id)',
  ];
}

enum LocalSyncStatus { pending, syncing, synced, conflict, rejected }

enum SyncEntityType {
  vital('VITAL'),
  symptom('SYMPTOM'),
  activity('ACTIVITY'),
  medication('MEDICATION'),
  doseLog('DOSE_LOG');

  const SyncEntityType(this.wire);

  final String wire;

  static SyncEntityType fromWire(String value) =>
      values.firstWhere((SyncEntityType e) => e.wire == value);
}
