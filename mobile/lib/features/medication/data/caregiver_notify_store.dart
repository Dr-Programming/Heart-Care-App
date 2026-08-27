import 'dart:convert';

import '../../../core/db/daos/preferences_dao.dart';

/// The "Notify caregiver if missed" toggle + phone number (Decision B of
/// docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md). Local-only —
/// nothing in the backend or sync payload supports actually notifying a
/// caregiver yet. Never persisted to the `Medications` Drift table (that
/// schema is core-owned and off-limits) — stored as a `Preferences` entry
/// per medication instead, the same pattern already used for this
/// feature's other local-only state.
class CaregiverNotifySettings {
  const CaregiverNotifySettings({required this.enabled, required this.phone});

  final bool enabled;
  final String phone;

  static const CaregiverNotifySettings empty = CaregiverNotifySettings(enabled: false, phone: '');
}

class CaregiverNotifyStore {
  const CaregiverNotifyStore(this._prefs);

  final PreferencesDao _prefs;

  String _keyFor(String medicationClientRecordId) => 'm3_caregiver_$medicationClientRecordId';

  Future<CaregiverNotifySettings> get(String medicationClientRecordId) async {
    final String? raw = await _prefs.get(_keyFor(medicationClientRecordId));
    if (raw == null) return CaregiverNotifySettings.empty;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return CaregiverNotifySettings(
      enabled: json['enabled'] as bool? ?? false,
      phone: json['phone'] as String? ?? '',
    );
  }

  Future<void> set(String medicationClientRecordId, CaregiverNotifySettings settings) {
    return _prefs.set(
      _keyFor(medicationClientRecordId),
      jsonEncode(<String, dynamic>{'enabled': settings.enabled, 'phone': settings.phone}),
    );
  }
}
