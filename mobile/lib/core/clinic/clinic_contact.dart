import '../db/daos/preferences_dao.dart';
import '../caregiver/caregiver_contact.dart';

/// The patient's clinic: who to call when readings keep coming in high.
typedef ClinicContact = SavedContact;

class ClinicContactStore extends ContactStore {
  const ClinicContactStore(PreferencesDao prefs) : super(prefs, storageKey);

  static const String storageKey = 'clinic_contact';
}
