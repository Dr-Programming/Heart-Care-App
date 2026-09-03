import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/presentation/screens/vital_form_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

class _FakeVitalsRepository implements VitalsRepository {
  VitalReading? logged;
  double? heightCm;
  VitalReading? stubbedLatest;

  @override
  Future<void> log(VitalReading reading) async => logged = reading;

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(const <VitalReading>[]);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => stubbedLatest;

  @override
  Future<double?> patientHeightCm() async => heightCm;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  late _FakeVitalsRepository repo;
  late List<Override> overrides;

  setUp(() {
    repo = _FakeVitalsRepository();
    overrides = <Override>[vitalsRepositoryProvider.overrideWithValue(repo)];
  });

  testWidgets('shows two fields for blood pressure, the default type', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    // 2 value fields (systolic, diastolic) + the always-present note field.
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('shows three fields after switching to cholesterol', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.tap(find.text('vitals.type.cholesterol'.tr()));
    await tester.pumpAndSettle();
    // 3 value fields (ldl, hdl, total) + the always-present note field.
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('an out-of-range value is blocked before submit', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.enterText(find.byType(TextField).at(0), '500'); // systolic
    await tester.enterText(find.byType(TextField).at(1), '80'); // diastolic
    await tester.tap(find.text('common.save'.tr()));
    await tester.pumpAndSettle();

    expect(repo.logged, isNull);
    expect(
      find.text(
        'errors.outOfRange'.tr(
          namedArgs: <String, String>{'min': '40', 'max': '300'},
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'saving a systolic of 190 shows the emergency status and its action',
    (WidgetTester tester) async {
      await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
      await tester.enterText(find.byType(TextField).at(0), '190');
      await tester.enterText(find.byType(TextField).at(1), '100');
      await tester.tap(find.text('common.save'.tr()));
      await tester.pumpAndSettle();

      expect(repo.logged, isNotNull);
      expect(repo.logged!.flagged, isTrue);
      expect(
        find.text('clinical.severity.${Severity.emergency.name}'.tr()),
        findsOneWidget,
      );
      expect(find.text(actionKeyFor(Severity.emergency).tr()), findsOneWidget);
    },
  );

  testWidgets('renders correctly in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const VitalFormScreen(),
      overrides: overrides,
      language: AppLanguage.am,
    );
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('hints the last glucose reading when one exists', (
    WidgetTester tester,
  ) async {
    repo.stubbedLatest = VitalReading(
      clientRecordId: 'prev',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.8},
      flagged: false,
      measuredAt: DateTime(2026, 8, 29),
    );
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.tap(find.text('vitals.type.glucose'.tr()));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(field.decoration?.hintText, '5.8');
  });
}
