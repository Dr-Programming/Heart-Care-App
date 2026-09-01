import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../models/patient_profile_model.dart';

class ProfileRemoteDatasource {
  final Dio dio;

  ProfileRemoteDatasource(this.dio);

  /// Never throws for "no profile yet" — the backend returns a 200 all-null
  /// skeleton in that case, which decodes to an empty [PatientProfileModel]
  /// just like any other successful response.
  Future<PatientProfileModel> getProfile() async {
    try {
      final response = await dio.get(ApiEndpoints.patientMe);
      final envelope = ApiResponse<PatientProfileModel>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => PatientProfileModel.fromJson(data as Map<String, dynamic>),
      );
      return envelope.data ?? const PatientProfileModel();
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  /// Always sends the FULL model. The backend replaces the entire profile on
  /// PUT — omitted fields are cleared to null, not left untouched.
  Future<PatientProfileModel> saveProfile(PatientProfileModel model) async {
    try {
      final response = await dio.put(
        ApiEndpoints.patientMe,
        data: model.toJson(),
      );
      final envelope = ApiResponse<PatientProfileModel>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => PatientProfileModel.fromJson(data as Map<String, dynamic>),
      );
      return envelope.data ?? model;
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }
}