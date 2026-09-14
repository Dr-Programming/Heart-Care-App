import '../entities/patient_profile.dart';

abstract interface class ProfileRepository {
  Future<PatientProfile> getProfile(String userId);

  Future<void> saveProfile(PatientProfile profile);

  Future<bool> isDirty(String userId);

  Future<void> retryPendingSave(String userId);

  Future<void> deleteProfile(String userId);
}
