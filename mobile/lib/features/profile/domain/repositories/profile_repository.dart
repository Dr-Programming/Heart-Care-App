import '../entities/patient_profile.dart';

abstract class ProfileRepository {
  /// Returns the current patient's profile. Never throws for "no profile
  /// yet" — returns an empty PatientProfile (all fields null) in that case,
  /// matching the backend's GET /patients/me behavior.
  Future<PatientProfile> getProfile();

  /// Saves the FULL profile. Callers must always pass the complete object,
  /// never a partial one — PUT /patients/me is a full replace.
  Future<PatientProfile> saveProfile(PatientProfile profile);

  /// Sets the device-local language preference immediately, and attempts
  /// to sync it to the profile's preferredLanguage field opportunistically.
  Future<void> setLanguage(String languageCode);
}