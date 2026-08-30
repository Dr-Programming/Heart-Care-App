import 'dart:convert';

import '../../../core/db/daos/preferences_dao.dart';

/// The "Instructions" field (After meal / With food / Before meal), added in
/// the second Figma-fidelity follow-up. Local-only — nothing in the backend
/// or sync payload supports storing dosing instructions yet. Never persisted
/// to the `Medications` Drift table (that schema is core-owned and
/// off-limits) — stored as a `Preferences` entry per medication instead, the
/// same pattern already used for this feature's other local-only state (see
/// `CaregiverNotifyStore`).
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
