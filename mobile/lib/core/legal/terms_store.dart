import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';

/// Raise when the "Before you start" text changes in a way patients must
/// agree to again; everyone who accepted an older version sees it once more.
const int currentTermsVersion = 1;

/// Whether this phone has agreed to the terms and privacy notice. Kept with
/// the phone's other settings (like the language), not with a patient.
class TermsStore {
  const TermsStore(this._prefs);

  final PreferencesDao _prefs;

  Future<bool> hasAccepted() async {
    final String? raw = await _prefs.get(PreferenceKeys.termsAcceptedVersion);
    final int? version = raw == null ? null : int.tryParse(raw);
    return version != null && version >= currentTermsVersion;
  }

  Future<void> accept() =>
      _prefs.set(PreferenceKeys.termsAcceptedVersion, '$currentTermsVersion');
}
