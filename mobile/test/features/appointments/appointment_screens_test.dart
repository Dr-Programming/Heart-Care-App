import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/notifications/one_time_reminders.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/shell/home_card.dart';
import 'package:libu_care/core/shell/home_screen.dart';
import 'package:libu_care/features/appointments/data/appointment_store.dart';
import 'package:libu_care/features/appointments/domain/appointment.dart';
import 'package:libu_care/features/appointments/presentation/appointment_home_card.dart';
import 'package:libu_care/features/appointments/presentation/screens/appointment_form_screen.dart';
import 'package:libu_care/features/appointments/presentation/screens/appointments_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

class _NoReminders implements OneTimeReminders {
  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {}

  @override
  Future<void> cancelWithPrefix(String prefix) async {}
}

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides() => <Override>[
    appDatabaseProvider.overrideWithValue(db),
    oneTimeRemindersProvider.overrideWithValue(_NoReminders()),
    homeCardsProvider.overrideWithValue(<HomeCard>[appointmentHomeCard()]),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
    pendingSyncCountProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
  ];

  Future<void> add(Appointment a) =>
      AppointmentStore(db.preferencesDao).save(a);

  DateTime inDays(int days, {int hour = 10}) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day + days, hour);
  }

  testWidgets('Home invites the patient to add their next visit', (
    tester,
  ) async {
    await pumpApp(tester, const HomeScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('appointments.homeEmpty'.tr()), findsOneWidget);
    expect(find.byKey(const Key('appointmentHomeSummary')), findsOneWidget);
  });

  testWidgets('a visit tomorrow shows on Home with how to prepare', (
    tester,
  ) async {
    await tester.runAsync(
      () => add(Appointment(id: 'a', at: inDays(1), place: 'Black Lion')),
    );
    await pumpApp(tester, const HomeScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('Black Lion'), findsOneWidget);
    expect(find.text('appointments.tomorrow'.tr()), findsOneWidget);
    expect(find.text('appointments.prepare.title'.tr()), findsOneWidget);
  });

  testWidgets('a visit next week shows without the preparation list yet', (
    tester,
  ) async {
    await tester.runAsync(() => add(Appointment(id: 'a', at: inDays(6))));
    await pumpApp(tester, const HomeScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'appointments.inDays'.tr(namedArgs: <String, String>{'days': '6'}),
      ),
      findsOneWidget,
    );
    expect(find.text('appointments.prepare.title'.tr()), findsNothing);
  });

  testWidgets('the list separates upcoming and past visits', (tester) async {
    await tester.runAsync(() async {
      await add(Appointment(id: 'next', at: inDays(3), place: 'Black Lion'));
      await add(
        Appointment(id: 'old', at: inDays(-10), place: 'Tikur Anbessa'),
      );
    });
    await pumpApp(tester, const AppointmentsScreen(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('appointments.upcoming'.tr()), findsOneWidget);
    expect(find.text('appointments.past'.tr()), findsOneWidget);
    expect(find.byKey(const Key('appointment_next')), findsOneWidget);
    expect(find.byKey(const Key('appointment_old')), findsOneWidget);
  });

  testWidgets('saving without a date asks for one', (tester) async {
    await pumpApp(
      tester,
      const AppointmentFormScreen(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('appointmentSave')));
    await tester.tap(find.byKey(const Key('appointmentSave')));
    await tester.pumpAndSettle();

    expect(find.text('appointments.form.whenRequired'.tr()), findsOneWidget);
  });

  testWidgets(
    'a new appointment starts with the saved clinic and all three reminders',
    (tester) async {
      await tester.runAsync(
        () => db.preferencesDao.set(
          'clinic_contact',
          '{"name":"Black Lion","phone":"0911223344"}',
        ),
      );
      await pumpApp(
        tester,
        const AppointmentFormScreen(),
        overrides: overrides(),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Black Lion'), findsOneWidget);
      for (final ReminderTiming t in ReminderTiming.values) {
        final CheckboxListTile box = tester.widget(
          find.byKey(Key('appointmentReminder_${t.code}')),
        );
        expect(box.value, isTrue);
      }
    },
  );
}
