import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/app/app_wiring.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/core/theme/app_theme.dart';

import '../../helpers/fake_dio.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

class _FakeTokenStore extends TokenStore {
  _FakeTokenStore() : super(const FlutterSecureStorage());

  String? _value;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;
}

String _jwt({required DateTime exp}) {
  String segment(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final String header = segment(<String, dynamic>{'alg': 'none'});
  final String payload = segment(<String, dynamic>{
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.signature';
}

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late FakeDio http;
  late _FakeTokenStore tokens;

  setUp(() async {
    db = testDatabase();
    http = FakeDio()..stubAll(FakeResponse.offline());
    tokens = _FakeTokenStore();

    await tokens.write(_jwt(exp: DateTime.now().add(const Duration(days: 7))));
    await db.cachedUserDao.save(
      CachedUsersCompanion.insert(
        id: 'u1',
        name: 'Abebe Girma',
        phone: '+251911234567',
        preferredLanguage: 'en',
        role: 'PATIENT',
      ),
    );
    await LanguageStore(db.preferencesDao).write(AppLanguage.en);
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );

  Future<void> boot(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        ...featureOverrides(),
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(http.dio),
        tokenStoreProvider.overrideWithValue(tokens),
        isOnlineProvider.overrideWithValue(() async => false),
        connectivityStreamProvider.overrideWithValue(const Stream<bool>.empty()),
        onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = container.read(routerProvider);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: AppLanguage.values
                .map((AppLanguage l) => l.locale)
                .toList(growable: false),
            path: 'assets/translations',
            fallbackLocale: AppLanguage.en.locale,
            useFallbackTranslations: true,
            child: Builder(
              builder: (BuildContext context) => MaterialApp.router(
                theme: AppTheme.light(context.locale.languageCode),
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await settle(tester);
  }

  testWidgets('editing the profile updates the Profile screen without a restart', (
    WidgetTester tester,
  ) async {
    await boot(tester);

    await tester.tap(find.byTooltip('profile.title'.tr()));
    await settle(tester);
    expect(find.text('profile.empty.title'.tr()), findsOneWidget);

    await tester.tap(find.byTooltip('common.edit'.tr()));
    await settle(tester);

    await tester.enterText(
      find.byKey(const Key('profile_edit_birthYear_field')),
      '1970',
    );
    await tester.pump();
    await tester.tap(find.text('common.save'.tr()));
    await settle(tester);

    expect(find.text('profile.empty.title'.tr()), findsNothing);
    expect(find.text('1970'), findsOneWidget);
  });
}
