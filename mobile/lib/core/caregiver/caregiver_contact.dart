import 'dart:convert';

import '../db/daos/preferences_dao.dart';

/// A name and phone number the patient saved to call: their caregiver in an
/// emergency, or their clinic when readings stay high. Kept on this phone
/// only, with the patient's other data, so it is cleared when a different
/// patient signs in.
class SavedContact {
  const SavedContact({required this.name, required this.phone});

  final String name;
  final String phone;

  /// The name, or the number when no name was given.
  String get displayName => name.isEmpty ? phone : name;

  @override
  bool operator ==(Object other) =>
      other is SavedContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}

/// The person the patient calls in an emergency: the clinician's pathway is
/// "call the emergency contact".
typedef CaregiverContact = SavedContact;

/// One saved contact in the preferences table, under [key].
class ContactStore {
  const ContactStore(this._prefs, this.key);

  final PreferencesDao _prefs;
  final String key;

  Future<SavedContact?> read() async => parse(await _prefs.get(key));

  /// The contact stored as [raw], or null when there is none or it is unreadable.
  static SavedContact? parse(String? raw) {
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(raw);
      if (json is! Map || json['phone'] is! String) return null;
      return SavedContact(
        name: (json['name'] as String?) ?? '',
        phone: json['phone'] as String,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> save(SavedContact contact) => _prefs.set(
    key,
    jsonEncode(<String, String>{
      'name': contact.name.trim(),
      'phone': contact.phone.trim(),
    }),
  );

  Future<void> clear() => _prefs.remove(key);
}

class CaregiverContactStore extends ContactStore {
  const CaregiverContactStore(PreferencesDao prefs)
    : super(prefs, 'caregiver_contact');
}

/// Accepts local (09…) and international (+251…) numbers: 9 to 15 digits,
/// an optional leading +, spaces allowed.
String? validateCaregiverPhone(String value) {
  final String compact = value.replaceAll(' ', '');
  if (compact.isEmpty) return 'profile.caregiver.phoneRequired';
  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(compact)) {
    return 'profile.caregiver.phoneInvalid';
  }
  return null;
}
