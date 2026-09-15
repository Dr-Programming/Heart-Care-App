import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/patient_profile_model.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PatientProfileModel> getProfile() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.patientMe,
    );
    return _unwrap(response);
  }

  Future<PatientProfileModel> saveProfile(PatientProfileModel profile) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      ApiEndpoints.patientMe,
      data: profile.toJson(),
    );
    return _unwrap(response);
  }

  PatientProfileModel _unwrap(Response<dynamic> response) {
    final ApiResponse<PatientProfileModel> envelope =
        ApiResponse<PatientProfileModel>.fromJson(
          response.data as Map<String, dynamic>,
          (Object? data) =>
              PatientProfileModel.fromJson(data as Map<String, dynamic>),
        );
    return envelope.data as PatientProfileModel;
  }
}
