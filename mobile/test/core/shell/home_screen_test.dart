import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/shell/home_card.dart';
import 'package:libu_care/core/shell/home_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides({
    List<HomeCard> cards = const <HomeCard>[],
    bool online = true,
    int pending = 0,
  }) {
    return <Override>[
      appDatabaseProvider.overrideWithValue(db),
      homeCardsProvider.overrideWithValue(cards),
      onlineStatusProvider.overrideWith(
        (Ref ref) => Stream<bool>.value(online),
      ),
      pendingSyncCountProvider.overrideWith(
        (Ref ref) => Stream<int>.value(pending),
      ),
    ];
  }

  HomeCard card(String id, int order, String text) => HomeCard(
    id: id,
    order: order,
    builder: (BuildContext context) => Text(text),
  );

  testWidgets('greets the user from the local cache, with no network', (
    WidgetTester tester,
  ) async {
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value('u-1'),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );

    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(online: false),
    );

    expect(find.text('Hello, Abebe'), findsOneWidget);
  });

  testWidgets('falls back to a generic greeting when nothing is cached', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());

    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('shows an empty state when no feature has registered a card', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());

    expect(find.text('Nothing to show yet'), findsOneWidget);
  });

  testWidgets('renders registered cards in order', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(
        cards: <HomeCard>[
          card('vitals-latest', 200, 'Latest vitals'),
          card('meds-today', 100, 'Doses today'),
        ],
      ),
    );

    final double medsY = tester.getTopLeft(find.text('Doses today')).dy;
    final double vitalsY = tester.getTopLeft(find.text('Latest vitals')).dy;
    expect(
      medsY,
      lessThan(vitalsY),
      reason: 'lower HomeCard.order renders first',
    );
  });

  testWidgets('warns the user when offline', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(online: false),
    );

    expect(
      find.text('You are offline. Anything you record is saved on this phone.'),
      findsOneWidget,
    );
  });

  testWidgets('reports how many records are waiting to sync', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides(pending: 3));

    expect(find.text('3 records waiting to send'), findsOneWidget);
  });
}
