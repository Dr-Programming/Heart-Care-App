import '../../../../core/localization/language.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class Register {
  const Register(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) =>
      _repository.register(phone: phone, pin: pin, name: name, language: language);
}
