// Author: Lachlan Smith
// Last updated by: Lachlan Smith

import '../repositories/auth_repository.dart';

class Logout {
  const Logout(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
