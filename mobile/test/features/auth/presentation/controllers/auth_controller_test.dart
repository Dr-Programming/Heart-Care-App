import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_controller.dart';

import '../../../../helpers/test_database.dart';

const _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

class _FakeAuthRepository implements AuthRepository {
  AuthUser? stored;
  Object? loginError;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    if (loginError != null) throw loginError!;
    stored = _user;
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    stored = _user;
    return _user;
  }

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<void> logout() async => stored = null;

  @override
  Future<AuthUser?> cachedUser() async => stored;

  @override
  Future<bool> isSignedIn() async => stored != null;

  @override
  Future<bool> needsOnboarding() async => false;
}

void main() {
  
  
  
  
  
  
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  ProviderContainer makeContainer(_FakeAuthRepository repo) {
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('cold start with a stored session restores from disk with no request', () async {
    final repo = _FakeAuthRepository()..stored = _user;
    final container = makeContainer(repo);

    final state = await container.read(authControllerProvider.future);

    expect(state, isA<AuthState>());
    expect(state.isAuthenticated, isTrue);
    expect(state.user, _user);
  });

  test('login moves through loading to authenticated', () async {
    final repo = _FakeAuthRepository();
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future); 

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(phone: '+251911234567', pin: '1234');

    final state = container.read(authControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.isAuthenticated, isTrue);
    expect(state.value!.user, _user);
  });

  test('a login failure lands in AsyncError carrying the Failure', () async {
    final repo = _FakeAuthRepository()..loginError = const InvalidCredentialsFailure('Invalid phone or PIN');
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(phone: '+251911234567', pin: '0000');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvalidCredentialsFailure>());
  });

  test('sign-out returns to unauthenticated', () async {
    final repo = _FakeAuthRepository()..stored = _user;
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future);

    final controller = container.read(authControllerProvider.notifier);
    await controller.signOut();

    expect(repo.stored, isNull);
    final state = container.read(authControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.isAuthenticated, isFalse);
    expect(state.value!.user, isNull);
  });

  test('a successful login refreshes realAuthGateProvider so the router sees the new session', () async {
    final repo = _FakeAuthRepository();
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future);

    
    
    
    await container.read(realAuthGateProvider.notifier).refresh();
    expect(container.read(realAuthGateProvider).isSignedIn, isFalse);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(phone: '+251911234567', pin: '1234');

    expect(container.read(realAuthGateProvider).isSignedIn, isTrue);
  });

  test('sign-out refreshes realAuthGateProvider back to signed out', () async {
    final repo = _FakeAuthRepository()..stored = _user;
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future);
    await container.read(realAuthGateProvider.notifier).refresh();
    expect(container.read(realAuthGateProvider).isSignedIn, isTrue);

    final controller = container.read(authControllerProvider.notifier);
    await controller.signOut();

    expect(container.read(realAuthGateProvider).isSignedIn, isFalse);
  });

  test('a login failure does not touch realAuthGateProvider', () async {
    final repo = _FakeAuthRepository()..loginError = const InvalidCredentialsFailure('Invalid phone or PIN');
    final container = makeContainer(repo);
    await container.read(authControllerProvider.future);
    await container.read(realAuthGateProvider.notifier).refresh();
    expect(container.read(realAuthGateProvider).isSignedIn, isFalse);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(phone: '+251911234567', pin: '0000');

    expect(container.read(realAuthGateProvider).isSignedIn, isFalse);
  });
}
