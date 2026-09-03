import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({required String phone, required String pin}) =>
      _repository.login(phone: phone, pin: pin);
}
