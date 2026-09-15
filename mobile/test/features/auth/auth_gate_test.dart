import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/router/auth_gate.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';

import '../../helpers/test_database.dart';

const _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);






class _FakeAuthRepository implements AuthRepository {
  bool _signedIn = true;

  bool _needsOnboarding = false;

  int isSignedInCalls = 0;
  int needsOnboardingCalls = 0;

  void setSignedIn(bool value) => _signedIn = value;

  void setNeedsOnboarding(bool value) => _needsOnboarding = value;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async => _user;

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async => _user;

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<void> logout() async {
    _signedIn = false;
  }

  @override
  Future<AuthUser?> cachedUser() async => _signedIn ? _user : null;

  @override
  Future<bool> isSignedIn() async {
    isSignedInCalls++;
    return _signedIn;
  }

  @override
  Future<bool> needsOnboarding() async {
    needsOnboardingCalls++;
    return _needsOnboarding;
  }
}




class _ThrowingAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> login({required String phone, required String pin}) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async => throw UnimplementedError();

  @override
  Future<AuthUser> getMe() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> cachedUser() async => null;

  @override
  Future<bool> isSignedIn() async => throw Exception('keystore unavailable');

  @override
  Future<bool> needsOnboarding() async => false;
}

void main() {
  late AppDatabase db;
  late _FakeAuthRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    fakeRepo = _FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test('build() returns an unresolved gate synchronously', () {
    final AuthGate gate = container.read(realAuthGateProvider);

    expect(gate.isResolved, isFalse);
    expect(gate.isSignedIn, isFalse);
    expect(gate.hasChosenLanguage, isFalse);
    expect(gate.needsOnboarding, isFalse);
  });

  test(
    'after resolution the gate reflects the repository and language store, '
    'with no network call made',
    () async {
      fakeRepo
        ..setSignedIn(true)
        ..setNeedsOnboarding(true);
      await container.read(languageStoreProvider).write(AppLanguage.en);

      
      
      await container.read(realAuthGateProvider.notifier).refresh();
      final AuthGate gate = container.read(realAuthGateProvider);

      expect(gate.isResolved, isTrue);
      expect(gate.isSignedIn, isTrue);
      expect(gate.hasChosenLanguage, isTrue);
      expect(gate.needsOnboarding, isTrue);
      
      
      expect(fakeRepo.isSignedInCalls, greaterThan(0));
      expect(fakeRepo.needsOnboardingCalls, greaterThan(0));
    },
  );

  test('a signed-out fake repository resolves to isSignedIn: false', () async {
    fakeRepo.setSignedIn(false);

    await container.read(realAuthGateProvider.notifier).refresh();
    final AuthGate gate = container.read(realAuthGateProvider);

    expect(gate.isResolved, isTrue);
    expect(gate.isSignedIn, isFalse);
    
    
    expect(gate.needsOnboarding, isFalse);
  });

  test('refresh() can be called again and updates the state again', () async {
    fakeRepo.setSignedIn(false);
    await container.read(realAuthGateProvider.notifier).refresh();
    expect(container.read(realAuthGateProvider).isSignedIn, isFalse);

    
    
    fakeRepo
      ..setSignedIn(true)
      ..setNeedsOnboarding(true);
    await container.read(realAuthGateProvider.notifier).refresh();
    final AuthGate gate = container.read(realAuthGateProvider);

    expect(gate.isResolved, isTrue);
    expect(gate.isSignedIn, isTrue);
    expect(gate.needsOnboarding, isTrue);
  });

  
  
  
  
  test(
    'a repository that throws on isSignedIn resolves to a signed-out, '
    'resolved gate rather than staying unresolved',
    () async {
      final ProviderContainer throwingContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
        ],
      );
      addTearDown(throwingContainer.dispose);

      await throwingContainer.read(realAuthGateProvider.notifier).refresh();
      final AuthGate gate = throwingContainer.read(realAuthGateProvider);

      expect(gate.isResolved, isTrue);
      expect(gate.isSignedIn, isFalse);
      expect(gate.hasChosenLanguage, isFalse);
      expect(gate.needsOnboarding, isFalse);
    },
  );
}
