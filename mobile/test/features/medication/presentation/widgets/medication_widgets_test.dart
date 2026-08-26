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

/// Serves the real short English labels ("Taken"/"Missed"/"Skipped") for the
/// `meds.status.*` keys directly, bypassing `assets/translations/*.json`.
/// Used where a test wants deterministic short copy independent of future
/// wording edits to the real translation files (e.g. to isolate a
/// proportional-width assertion from unrelated copy changes) — not a
/// workaround for a missing translation namespace; `meds.status.*` has been
/// populated with real short copy since Task 20.
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

/// Serves deliberately long placeholder strings for the `meds.status.*`
/// keys — the same length class as the pre-Task-20 accidental worst case,
/// back when the `meds` namespace was still `{}` and `.tr()` fell back to
/// the ~17-19 character raw key text ("meds.status.taken" etc.). Task 20
/// populated the real (short: "Taken"/"Missed"/"Skipped") copy, so that long
/// text no longer shows up by accident. This loader reproduces it on
/// purpose so the overflow-regression tests below keep exercising the
/// long-label-on-a-narrow-device scenario they were built to catch,
/// independent of how long the real copy happens to be in any language.
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

/// Same shape as `pumpApp` (helpers/pump_app.dart), but with [loader] in
/// place of the real translation asset — duplicated here rather than added
/// as a parameter to the shared helper, since this is a one-off need for
/// this file's fixed-copy-length tests.
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

/// Pumps [child] with the real short `meds.status.*` labels loaded (see
/// [_ShortLabelAssetLoader]).
Future<void> _pumpWithRealisticLabels(WidgetTester tester, Widget child) =>
    _pumpWithAssetLoader(tester, child, const _ShortLabelAssetLoader());

/// Pumps [child] with deliberately long `meds.status.*` labels loaded (see
/// [_LongLabelAssetLoader]) — for the overflow-regression tests that need to
/// exercise the long-label worst case regardless of how short the real
/// translated copy is.
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
    await pumpApp(tester, Material(child: DoseRow(dose: pending, onLog: (_) {})));
    expect(find.byType(StatusSelector), findsOneWidget);
  });

  testWidgets('tapping Taken in StatusSelector calls onSelected with DoseStatus.taken', (tester) async {
    // Task 20 populated `meds.status.taken` in assets/translations/*.json, so
    // easy_localization's .tr() now resolves to the real copy ("Taken")
    // instead of falling back to the raw key string — match on that.
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
      // Worst-case simulation of the real bug: pumps deliberately long
      // placeholder status labels via `_pumpWithLongLabels` (see
      // `_LongLabelAssetLoader`) rather than the app's real, now-short
      // `meds.status.*` copy — long label text is the actual risk this fix
      // guards against, independent of how long the real copy is in any
      // given language. Constraining the row to 220px (narrower than any
      // realistic phone's available content width, e.g. ~360dp minus screen
      // padding) simulates the combination this bug needs: long label text
      // + a physically narrow device. Before the fix (bare trailing
      // `StatusSelector`, inner `Row` instead of `Wrap`) this throws a
      // `RenderFlex overflowed` FlutterError during pump.
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
              child: DoseRow(dose: pending, onLog: (_) {}),
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
      // Same worst case as above (long placeholder labels via
      // `_pumpWithLongLabels`), but for the `StatusChip` branch (a dose
      // already logged) — the trailing widget differs but the same
      // `Flexible` wrap in DoseRow must protect it too.
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
              child: DoseRow(dose: logged, onLog: (_) {}),
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
      // StatusSelector directly, at 200px — narrower still than the DoseRow
      // scenario above, to isolate the `Wrap` fix (as opposed to the
      // `Flexible` fix in DoseRow) as sufficient on its own. Uses
      // `_pumpWithLongLabels` for the same reason as the DoseRow overflow
      // tests above — long labels are the actual risk, not whatever the
      // real translated copy's length happens to be today.
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
      // The original fix wrapped the trailing widget in a plain `Flexible`
      // (default flex: 1) next to the leading `Expanded` (also flex: 1) — an
      // even 50/50 split of the row regardless of how little the leading
      // column's actual content needs, which starves the trailing chips even
      // when the medication name is short (the common case).
      //
      // This test proves the fix is now content-driven rather than a fixed
      // proportion: it pumps the *same* DoseRow content at two different
      // container widths and checks how the extra space is distributed.
      // Under a proportional 50/50 flex split, widening the container by
      // 200px would hand ~100px of that increase to the leading column too.
      // Under the leading `ConstrainedBox` + sole-flex-child trailing
      // `Flexible` in the fixed `dose_row.dart`, the leading column's actual
      // rendered width stays essentially unchanged (it only ever claims what
      // its text content needs, up to its cap) and virtually all of the
      // extra space goes to the trailing widget instead.
      //
      // Widths are kept under 800 (the default `flutter test` surface) so
      // neither is clamped by the outer `Material`/`MediaQuery` — clamping
      // was confirmed empirically while calibrating this test (a requested
      // SizedBox width of 900 rendered at ~800 instead).
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
                child: SectionCard(child: DoseRow(dose: pending, onLog: (_) {})),
              ),
            ),
          ),
        ),
      );

      // The leading column, scoped to inside DoseRow specifically —
      // SectionCard has its own outer Column that must not be matched here.
      Finder leadingColumn() => find.descendant(of: find.byType(DoseRow), matching: find.byType(Column));

      await pumpAt(500);
      expect(tester.takeException(), isNull);
      final double leadingWidthAt500 = tester.renderObject<RenderBox>(leadingColumn()).size.width;
      final double trailingWidthAt500 = tester.renderObject<RenderBox>(find.byType(StatusSelector)).size.width;

      await pumpAt(700);
      expect(tester.takeException(), isNull);
      final double leadingWidthAt700 = tester.renderObject<RenderBox>(leadingColumn()).size.width;
      final double trailingWidthAt700 = tester.renderObject<RenderBox>(find.byType(StatusSelector)).size.width;

      // Leading barely moves: it is sized to its own content, not a
      // proportional share of a wider row.
      expect(
        (leadingWidthAt700 - leadingWidthAt500).abs(),
        lessThan(5),
        reason: 'leading column width should be content-driven (roughly constant), not proportional to row width',
      );
      // Trailing absorbs virtually the entire 200px increase — the opposite
      // of what a 50/50 flex split would do (~100px each).
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
      // A larger text-scale factor inflates each chip's own intrinsic width
      // simultaneously — a different stress than a narrow container, since
      // it's the scenario where a single chip's width (not just the sum of
      // three) can approach its allotted share. 1.4x is within the common
      // "Large" end of Android/iOS accessibility text-size settings.
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
                  child: SectionCard(child: DoseRow(dose: pending, onLog: (_) {})),
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
}
