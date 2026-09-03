import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _user = AuthUser(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);

void main() {
  late MockAuthRepository repo;
  late bool online;

  // mocktail needs a concrete fallback for `any(named: 'language')` because
  // AppLanguage is a non-nullable custom type.
  setUpAll(() => registerFallbackValue(AppLanguage.en));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWithValue(() async => online),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = MockAuthRepository();
    online = true;
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    when(() => repo.logout()).thenAnswer((_) async {});
  });

  test('starts unauthenticated when there is no session', () async {
    final state = await container().read(authControllerProvider.future);
    expect(state, isA<AuthUnauthenticated>());
  });

  test('restores an authenticated session from cache with no network call', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => _user);
    final state = await container().read(authControllerProvider.future);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.name, 'Abebe Bekele');
    verifyNever(() => repo.getMe());
  });

  test('a valid token with no cached user, offline, is unauthenticated', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    online = false;
    expect(await container().read(authControllerProvider.future),
        isA<AuthUnauthenticated>());
    verifyNever(() => repo.getMe());
  });

  test('a valid token with no cached user, online, recovers via getMe', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    when(() => repo.getMe()).thenAnswer((_) async => _user);
    final state = await container().read(authControllerProvider.future);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.name, 'Abebe Bekele');
    verify(() => repo.getMe()).called(1);
  });

  test('a valid token with no cached user, online, but getMe fails -> unauthenticated',
      () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    when(() => repo.getMe())
        .thenThrow(const SessionExpiredFailure('Session expired'));
    expect(await container().read(authControllerProvider.future),
        isA<AuthUnauthenticated>());
  });

  test('login moves the state to authenticated', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier)
        .login(phone: '+251911234567', pin: '1234');
    expect(c.read(authControllerProvider).value, isA<AuthAuthenticated>());
  });

  test('a failed login surfaces as AsyncError carrying the Failure', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const InvalidCredentialsFailure('Invalid phone or PIN'));
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier)
        .login(phone: '+251911234567', pin: '9999');
    final state = c.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvalidCredentialsFailure>());
  });

  test('register authenticates on success', () async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: AppLanguage.am,
        );
    expect(c.read(authControllerProvider).value, isA<AuthAuthenticated>());
  });

  test('signOut clears the repository and returns to unauthenticated', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(authControllerProvider).value, isA<AuthUnauthenticated>());
    verify(() => repo.logout()).called(1);
  });
}
