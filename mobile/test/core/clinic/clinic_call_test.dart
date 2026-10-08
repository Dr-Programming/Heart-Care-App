import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinic/clinic_call.dart';
import 'package:libu_care/core/clinic/clinic_contact.dart';
import 'package:libu_care/core/clinic/clinic_home_cards.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/shell/home_card.dart';
import 'package:libu_care/core/shell/home_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late ClinicContactStore store;
  late List<String> dialled;

  setUp(() {
    db = testDatabase();
    store = ClinicContactStore(db.preferencesDao);
    dialled = <String>[];
  });
  tearDown(() => db.close());

  List<Override> overrides(List<HomeCard> cards) => <Override>[
    appDatabaseProvider.overrideWithValue(db),
    homeCardsProvider.overrideWithValue(cards),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
    pendingSyncCountProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
  ];

  Future<void> pumpOptions(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showClinicCallOptions(
            context,
            store,
            dial: (String number) async => dialled.add(number),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Call now" dials the saved clinic', (tester) async {
    await tester.runAsync(
      () => store.save(
        const ClinicContact(name: 'Tikur Anbessa', phone: '+251 911 000111'),
      ),
    );
    await pumpOptions(tester);

    expect(find.textContaining('Tikur Anbessa'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clinicCallNow')));
    await tester.pumpAndSettle();

    expect(dialled, <String>['+251 911 000111']);
  });

  testWidgets('"Not now" closes without calling', (tester) async {
    await tester.runAsync(
      () =>
          store.save(const ClinicContact(name: 'Clinic', phone: '0911000111')),
    );
    await pumpOptions(tester);

    await tester.tap(find.byKey(const Key('clinicNotNow')));
    await tester.pumpAndSettle();

    expect(dialled, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('with no clinic saved, it offers to add one, then to call it', (
    tester,
  ) async {
    await pumpOptions(tester);

    expect(find.text('clinic.call.noClinic'.tr()), findsOneWidget);
    await tester.tap(find.byKey(const Key('clinicAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('clinic_name')), 'Black Lion');
    await tester.enterText(find.byKey(const Key('clinic_phone')), '0911223344');
    await tester.tap(find.text('profile.clinic.save'.tr()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clinicCallNow')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clinicCallNow')));
    await tester.pumpAndSettle();
    expect(dialled, <String>['0911223344']);
  });

  testWidgets('Home shows the clinic card with a way to add the clinic', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(<HomeCard>[clinicHomeCard()]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clinicHomeCard')), findsOneWidget);
    expect(find.byKey(const Key('clinicHomeAdd')), findsOneWidget);
  });

  testWidgets('Home shows the saved clinic with a call button', (tester) async {
    await tester.runAsync(
      () => store.save(
        const ClinicContact(name: 'Black Lion', phone: '0911223344'),
      ),
    );
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(<HomeCard>[clinicHomeCard()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Black Lion'), findsOneWidget);
    expect(find.byKey(const Key('clinicHomeCall')), findsOneWidget);
  });

  testWidgets('three urgent readings put a "call your clinic" card on Home', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (int i = 1; i <= 3; i++) {
        await db
            .into(db.vitalsLogs)
            .insert(
              VitalsLogsCompanion.insert(
                clientRecordId: 'v$i',
                type: 'BLOOD_PRESSURE',
                valuesJson: jsonEncode(<String, int>{
                  'systolic': 150,
                  'diastolic': 95,
                }),
                measuredAt: DateTime.now().subtract(Duration(hours: i)),
              ),
            );
      }
    });
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(<HomeCard>[
        urgentClinicHomeCard(),
        clinicHomeCard(),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clinicUrgentCard')), findsOneWidget);
  });

  testWidgets('no "call your clinic" card without urgent readings', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const HomeScreen(),
      overrides: overrides(<HomeCard>[
        urgentClinicHomeCard(),
        clinicHomeCard(),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clinicUrgentCard')), findsNothing);
  });

  testWidgets(
    'after a third urgent reading a notice appears; tapping it offers the call',
    (tester) async {
      await tester.runAsync(() async {
        await store.save(
          const ClinicContact(name: 'Black Lion', phone: '0911223344'),
        );
        for (int i = 1; i <= 3; i++) {
          await db
              .into(db.vitalsLogs)
              .insert(
                VitalsLogsCompanion.insert(
                  clientRecordId: 'u$i',
                  type: 'BLOOD_PRESSURE',
                  valuesJson: jsonEncode(<String, int>{
                    'systolic': 150,
                    'diastolic': 95,
                  }),
                  measuredAt: DateTime.now().subtract(Duration(hours: i)),
                ),
              );
        }
      });
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () =>
                  remindToCallClinicIfNeeded(context, db: db, store: store),
              child: const Text('saved'),
            ),
          ),
        ),
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      await tester.tap(find.text('saved'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clinicReminderBanner')), findsOneWidget);
      await tester.tap(find.text('clinic.reminder.call'.tr()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clinicCallNow')), findsOneWidget);
    },
  );
}
