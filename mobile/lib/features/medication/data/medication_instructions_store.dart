import 'dart:convert';

import '../../../core/db/daos/preferences_dao.dart';

enum MedicationInstructions {
  none,
  afterMeal,
  withFood,
  beforeMeal;

  static MedicationInstructions fromWire(String? value) => switch (value) {
    'afterMeal' => MedicationInstructions.afterMeal,
    'withFood' => MedicationInstructions.withFood,
    'beforeMeal' => MedicationInstructions.beforeMeal,
    _ => MedicationInstructions.none,
  };
}

class MedicationInstructionsStore {
  const MedicationInstructionsStore(this._prefs);

  final PreferencesDao _prefs;

  String _keyFor(String medicationClientRecordId) => 'm3_instructions_$medicationClientRecordId';

  Future<MedicationInstructions> get(String medicationClientRecordId) async {
    final String? raw = await _prefs.get(_keyFor(medicationClientRecordId));
    if (raw == null) return MedicationInstructions.none;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return MedicationInstructions.fromWire(json['instructions'] as String?);
  }

  Future<void> set(String medicationClientRecordId, MedicationInstructions value) {
    return _prefs.set(
      _keyFor(medicationClientRecordId),
      jsonEncode(<String, dynamic>{'instructions': value.name}),
    );
  }
}
