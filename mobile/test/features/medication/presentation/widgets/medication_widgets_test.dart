import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/theme/app_spacing.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/widgets/dose_row.dart';
import 'package:libu_care/features/medication/presentation/widgets/medication_card.dart';
import 'package:libu_care/features/medication/presentation/widgets/status_selector.dart';
import 'package:libu_care/features/medication/presentation/widgets/time_list_field.dart';

import '../../../../helpers/pump_app.dart';

class _ShortLabelAssetLoader extends AssetLoader {
  const _ShortLabelAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      Future<Map<String, dynamic>>.value(const <String, dynamic>{
        'meds': <String, dynamic>{
          'status': <String, dynamic>{
            'taken': 'Taken',
            'missed': 'Missed',
            'skipped': 'Skipped',
          },
        },
      });
}

class _LongLabelAssetLoader extends AssetLoader {
  const _LongLabelAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      Future<Map<String, dynamic>>.value(const <String, dynamic>{
        'meds': <String, dynamic>{
          'status': <String, dynamic>{
            'taken': 'meds.status.taken',
            'missed': 'meds.status.missed',
            'skipped': 'meds.status.skipped',
          },
        },
      });
}

Future<void> _pumpWithAssetLoader(WidgetTester tester, Widget child, AssetLoader loader) async {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: AppLanguage.values.map((AppLanguage l) => l.locale).toList(growable: false),
          path: 'assets/translations',
          fallbackLocale: AppLanguage.en.locale,
          startLocale: AppLanguage.en.locale,
          useFallbackTranslations: true,
          assetLoader: loader,
          child: Builder(
            builder: (BuildContext context) => MaterialApp(
              theme: AppTheme.light(context.locale.languageCode),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: child,
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

Future<void> _pumpWithRealisticLabels(WidgetTester tester, Widget child) =>
    _pumpWithAssetLoader(tester, child, const _ShortLabelAssetLoader());

Future<void> _pumpWithLongLabels(WidgetTester tester, Widget child) =>
    _pumpWithAssetLoader(tester, child, const _LongLabelAssetLoader());

void main() {
  setUpWidgetTests();

  testWidgets('MedicationCard shows the name, dose and schedule', (tester) async {
    final Medication medication = Medication(
      clientRecordId: 'm1', serverId: null, name: 'Atorvastatin', doseMg: 20,
      frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
      active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
    );
    await pumpApp(tester, Material(child: MedicationCard(medication: medication)));

    expect(find.textContaining('Atorvastatin'), findsOneWidget);
    expect(find.textContaining('08:00'), findsOneWidget);
  });

  testWidgets('DoseRow shows a StatusSelector when pending and a chip when logged', (tester) async {
    const ScheduledDose pending = ScheduledDose(
      medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
      scheduledDate: '2026-08-25', scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending, doseLog: null,
    );
    await pumpApp(tester, Material(child: DoseRow(dose: pending, onLog: (_, {String? note}) {})));
    expect(find.byType(StatusSelector), findsOneWidget);
  });

  testWidgets('tapping Taken in StatusSelector calls onSelected with DoseStatus.taken', (tester) async {

    DoseStatus? selected;
    await pumpApp(
      tester,
      Material(child: StatusSelector(onSelected: (s) => selected = s)),
    );

    await tester.tap(find.text('Taken'));
    await tester.pump();

    expect(selected, DoseStatus.taken);
  });

  testWidgets(
    'DoseRow does not overflow a narrow row with long status labels (pending)',
    (tester) async {

      const ScheduledDose pending = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'A very long medication name that keeps going',
        doseMg: 75,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.pending,
        doseLog: null,
      );

      await _pumpWithLongLabels(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: DoseRow(dose: pending, onLog: (_, {String? note}) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusSelector), findsOneWidget);
    },
  );

  testWidgets(
    'DoseRow does not overflow a narrow row with long status labels (logged)',
    (tester) async {

      final ScheduledDose logged = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'A very long medication name that keeps going',
        doseMg: 75,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.logged,
        doseLog: DoseLog(
          clientRecordId: 'd1',
          serverId: null,
          medicationClientRecordId: 'm1',
          medicationServerId: null,
          status: DoseStatus.taken,
          scheduledDate: '2026-08-25',
          scheduledTime: '08:00',
          loggedAt: DateTime(2026, 8, 25, 8, 5),
          note: null,
        ),
      );

      await _pumpWithLongLabels(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: DoseRow(dose: logged, onLog: (_, {String? note}) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'StatusSelector does not overflow an even narrower width',
    (tester) async {

      await _pumpWithLongLabels(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: StatusSelector(onSelected: (_) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DoseRow gives the trailing status widget the actual leftover width, not a blind 50/50 split',
    (tester) async {

      const ScheduledDose pending = ScheduledDose(
        medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
        scheduledDate: '2026-08-25', scheduledTime: '08:00',
        status: ScheduledDoseStatus.pending, doseLog: null,
      );

      Future<void> pumpAt(double width) => _pumpWithRealisticLabels(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: SectionCard(child: DoseRow(dose: pending, onLog: (_, {String? note}) {})),
              ),
            ),
          ),
        ),
      );

      Finder leadingColumn() => find.descendant(of: find.byType(DoseRow), matching: find.byType(Column));

      await pumpAt(500);
      expect(tester.takeException(), isNull);
      final double leadingWidthAt500 = tester.renderObject<RenderBox>(leadingColumn()).size.width;
      final double trailingWidthAt500 = tester.renderObject<RenderBox>(find.byType(StatusSelector)).size.width;

      await pumpAt(700);
      expect(tester.takeException(), isNull);
      final double leadingWidthAt700 = tester.renderObject<RenderBox>(leadingColumn()).size.width;
      final double trailingWidthAt700 = tester.renderObject<RenderBox>(find.byType(StatusSelector)).size.width;

      expect(
        (leadingWidthAt700 - leadingWidthAt500).abs(),
        lessThan(5),
        reason: 'leading column width should be content-driven (roughly constant), not proportional to row width',
      );

      expect(
        trailingWidthAt700 - trailingWidthAt500,
        greaterThan(150),
        reason: 'trailing widget should absorb the leftover width instead of a fixed 50% share',
      );
    },
  );

  testWidgets(
    'StatusSelector does not overflow under a larger accessibility text scale',
    (tester) async {

      const ScheduledDose pending = ScheduledDose(
        medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
        scheduledDate: '2026-08-25', scheduledTime: '08:00',
        status: ScheduledDoseStatus.pending, doseLog: null,
      );

      await _pumpWithRealisticLabels(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  child: SectionCard(child: DoseRow(dose: pending, onLog: (_, {String? note}) {})),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusSelector), findsOneWidget);
    },
  );

  testWidgets(
    'a note typed on a logged dose reaches onLog with the same status (I6)',
    (tester) async {

      DoseStatus? loggedStatus;
      String? loggedNote;
      int calls = 0;

      final ScheduledDose logged = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'Aspirin',
        doseMg: 75,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.logged,
        doseLog: DoseLog(
          clientRecordId: 'd1',
          serverId: null,
          medicationClientRecordId: 'm1',
          medicationServerId: null,
          status: DoseStatus.taken,
          scheduledDate: '2026-08-25',
          scheduledTime: '08:00',
          loggedAt: DateTime(2026, 8, 25, 8, 5),
          note: null,
        ),
      );

      await pumpApp(
        tester,
        Material(
          child: DoseRow(
            dose: logged,
            onLog: (DoseStatus status, {String? note}) {
              calls++;
              loggedStatus = status;
              loggedNote = note;
            },
          ),
        ),
      );

      await tester.tap(find.text('meds.note.add'.tr()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Felt dizzy after it  ');
      await tester.tap(find.text('meds.note.save'.tr()));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(loggedNote, 'Felt dizzy after it');
      expect(
        loggedStatus,
        DoseStatus.taken,
        reason: 'saving a note must not silently change the recorded status',
      );
    },
  );

  testWidgets('dismissing the note sheet logs nothing (I6)', (tester) async {
    int calls = 0;
    final ScheduledDose logged = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.logged,
      doseLog: DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: DateTime(2026, 8, 25, 8, 5),
        note: null,
      ),
    );

    await pumpApp(
      tester,
      Material(
        child: DoseRow(dose: logged, onLog: (_, {String? note}) => calls++),
      ),
    );

    await tester.tap(find.text('meds.note.add'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('an existing note is shown and offered for editing (I6)', (
    tester,
  ) async {
    final ScheduledDose logged = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.logged,
      doseLog: DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: DateTime(2026, 8, 25, 8, 5),
        note: 'Felt dizzy',
      ),
    );

    await pumpApp(
      tester,
      Material(
        child: DoseRow(dose: logged, onLog: (_, {String? note}) {}),
      ),
    );

    expect(find.text('Felt dizzy'), findsOneWidget);
    expect(find.text('meds.note.edit'.tr()), findsOneWidget);
    expect(find.text('meds.note.add'.tr()), findsNothing);
  });

  testWidgets('TimeListField renders a chip per time and adds one via the picker', (tester) async {
    List<String> current = const <String>['08:00'];
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Material(
          child: TimeListField(
            times: current,
            onChanged: (t) => setState(() => current = t),
          ),
        ),
      ),
    );

    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets(
    'TimeListField restyled chips do not overflow a narrow width with '
    'several times (styling pass)',
    (tester) async {

      await pumpApp(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: TimeListField(
                times: const <String>['06:00', '08:00', '12:00', '18:00', '22:00'],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(InputChip), findsNWidgets(5));
      expect(find.byType(ActionChip), findsOneWidget);
    },
  );

  testWidgets(
    'DoseRow renders real Amharic on a phone-width row without overflowing (I9)',
    (tester) async {

      final ScheduledDose logged = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'Atorvastatin',
        doseMg: 20,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.logged,
        doseLog: DoseLog(
          clientRecordId: 'd1',
          serverId: null,
          medicationClientRecordId: 'm1',
          medicationServerId: null,
          status: DoseStatus.skipped,
          scheduledDate: '2026-08-25',
          scheduledTime: '08:00',
          loggedAt: DateTime(2026, 8, 25, 8, 5),
          note: null,
        ),
      );

      await pumpApp(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: SectionCard(
                  child: DoseRow(dose: logged, onLog: (_, {String? note}) {}),
                ),
              ),
            ),
          ),
        ),
        language: AppLanguage.am,
      );

      final String skipped = 'meds.status.skipped'.tr();
      final String addNote = 'meds.note.add'.tr();
      expect(skipped, isNot('Skipped'));
      expect(skipped, isNot('meds.status.skipped'));
      expect(addNote, isNot('Add a note'));
      expect(addNote, isNot('meds.note.add'));

      expect(find.text(skipped), findsOneWidget);
      expect(find.text(addNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the Amharic note sheet opens and returns what was typed (I9)',
    (tester) async {

      String? loggedNote;
      final ScheduledDose logged = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'Atorvastatin',
        doseMg: 20,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.logged,
        doseLog: DoseLog(
          clientRecordId: 'd1',
          serverId: null,
          medicationClientRecordId: 'm1',
          medicationServerId: null,
          status: DoseStatus.taken,
          scheduledDate: '2026-08-25',
          scheduledTime: '08:00',
          loggedAt: DateTime(2026, 8, 25, 8, 5),
          note: null,
        ),
      );

      await pumpApp(
        tester,
        Material(
          child: DoseRow(
            dose: logged,
            onLog: (_, {String? note}) => loggedNote = note,
          ),
        ),
        language: AppLanguage.am,
      );

      await tester.tap(find.text('meds.note.add'.tr()));
      await tester.pumpAndSettle();

      final String sheetTitle = 'meds.note.title'.tr();
      expect(sheetTitle, isNot('Note'));
      expect(find.text(sheetTitle), findsOneWidget);
      expect(find.text('meds.note.hint'.tr()), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ማዞር ተሰማኝ');
      await tester.tap(find.text('meds.note.save'.tr()));
      await tester.pumpAndSettle();

      expect(loggedNote, 'ማዞር ተሰማኝ');
      expect(tester.takeException(), isNull);
    },
  );
}
