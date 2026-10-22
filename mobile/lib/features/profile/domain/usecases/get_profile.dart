// Author: Thi Thuy Trang Nguyen
// Contributors: Thi Thuy Trang Nguyen, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

class GetProfile {
  const GetProfile(this._repository);
  final ProfileRepository _repository;

  Future<PatientProfile> call(String userId) => _repository.getProfile(userId);
}
