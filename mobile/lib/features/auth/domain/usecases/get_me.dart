import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class GetMe {
  const GetMe(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call() => _repository.getMe();
}
