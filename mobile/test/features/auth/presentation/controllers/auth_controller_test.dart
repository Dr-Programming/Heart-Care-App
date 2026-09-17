import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart'
    show isOnlineProvider;
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_controller.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(AppLanguage.en);
  });

  const AuthUser user = AuthUser(
    id: 'u1',
    name: 'Abebe Girma',
    phone: '+251911234567',
    preferredLanguage: 'en',
    role: 'PATIENT',
  );

  late MockAuthRepository repository;

  ProviderContainer makeContainer({bool online = true}) {
    repository = MockAuthRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        isOnlineProvider.overrideWithValue(() async => online),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build (session restore)', () {
    test('no valid token -> unauthenticated, cachedUser never read', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => false);

      final AuthState state = await container.read(
        authControllerProvider.future,
      );

      expect(state, isA<AuthUnauthenticated>());
      verifyNever(() => repository.cachedUser());
    });

    test('valid token + cached user -> authenticated, no getMe call', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => true);
      when(() => repository.cachedUser()).thenAnswer((_) async => user);

      final AuthState state = await container.read(
        authControllerProvider.future,
      );

      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.id, 'u1');
      verifyNever(() => repository.getMe());
    });

    test(
      'valid token + no cache + online -> calls getMe and authenticates',
      () async {
        final ProviderContainer container = makeContainer();
        when(() => repository.hasValidSession()).thenAnswer((_) async => true);
        when(() => repository.cachedUser()).thenAnswer((_) async => null);
        when(() => repository.getMe()).thenAnswer((_) async => user);

        final AuthState state = await container.read(
          authControllerProvider.future,
        );

        expect(state, isA<AuthAuthenticated>());
      },
    );

    test('valid token + no cache + getMe fails -> unauthenticated', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => true);
      when(() => repository.cachedUser()).thenAnswer((_) async => null);
      when(() => repository.getMe())
          .thenThrow(const SessionExpiredFailure('expired'));

      final AuthState state = await container.read(
        authControllerProvider.future,
      );

      expect(state, isA<AuthUnauthenticated>());
    });
  });

  group('login', () {
    test('success moves state to AuthAuthenticated', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => false);
      when(
        () => repository.login(
          phone: any(named: 'phone'),
          pin: any(named: 'pin'),
        ),
      ).thenAnswer((_) async => user);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(phone: '+251911234567', pin: '1234');

      final AsyncValue<AuthState> state = container.read(
        authControllerProvider,
      );
      expect(state.value, isA<AuthAuthenticated>());
    });

    test('failure surfaces as AsyncError carrying the Failure', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => false);
      when(
        () => repository.login(
          phone: any(named: 'phone'),
          pin: any(named: 'pin'),
        ),
      ).thenThrow(const InvalidCredentialsFailure('Invalid phone or PIN'));
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(phone: '+251911234567', pin: '0000');

      final AsyncValue<AuthState> state = container.read(
        authControllerProvider,
      );
      expect(state.hasError, isTrue);
      expect(state.error, isA<InvalidCredentialsFailure>());
    });
  });

  group('register', () {
    test('success moves state to AuthAuthenticated', () async {
      final ProviderContainer container = makeContainer();
      when(() => repository.hasValidSession()).thenAnswer((_) async => false);
      when(
        () => repository.register(
          phone: any(named: 'phone'),
          pin: any(named: 'pin'),
          name: any(named: 'name'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => user);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .register(
            phone: '+251911234567',
            pin: '1234',
            name: 'Abebe Girma',
            language: AppLanguage.en,
          );

      final AsyncValue<AuthState> state = container.read(
        authControllerProvider,
      );
      expect(state.value, isA<AuthAuthenticated>());
    });
  });

  group('signOut', () {
    test(
      'clears the repository session and returns to unauthenticated',
      () async {
        final ProviderContainer container = makeContainer();
        when(() => repository.hasValidSession()).thenAnswer((_) async => true);
        when(() => repository.cachedUser()).thenAnswer((_) async => user);
        when(() => repository.logout()).thenAnswer((_) async {});
        await container.read(authControllerProvider.future);

        await container.read(authControllerProvider.notifier).signOut();

        final AsyncValue<AuthState> state = container.read(
          authControllerProvider,
        );
        expect(state.value, isA<AuthUnauthenticated>());
        verify(() => repository.logout()).called(1);
      },
    );
  });
}
