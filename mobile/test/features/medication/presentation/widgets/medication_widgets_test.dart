import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/widgets/dose_row.dart';
import 'package:libu_care/features/medication/presentation/widgets/medication_card.dart';
import 'package:libu_care/features/medication/presentation/widgets/status_selector.dart';
import 'package:libu_care/features/medication/presentation/widgets/time_list_field.dart';

import '../../../../helpers/pump_app.dart';

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
    // 'meds.status.taken' is not yet populated in assets/translations/*.json
    // (Task 20's scope). easy_localization's .tr() falls back to the raw key
    // string for a missing key, so the rendered label is the key itself
    // rather than "Taken" — match on that until Task 20 adds the real copy.
    DoseStatus? selected;
    await pumpApp(
      tester,
      Material(child: StatusSelector(onSelected: (s) => selected = s)),
    );

    await tester.tap(find.text('meds.status.taken'));
    await tester.pump();

    expect(selected, DoseStatus.taken);
  });

  testWidgets(
    'DoseRow does not overflow a narrow row with long status labels (pending)',
    (tester) async {
      // Worst-case simulation of the real bug: `meds.status.*` is still an
      // unpopulated translation namespace, so `.tr()` falls back to the raw
      // key string ("meds.status.taken" etc.) — already longer than the
      // real English/Amharic copy will be. Constraining the row to 220px
      // (narrower than any realistic phone's available content width, e.g.
      // ~360dp minus screen padding) simulates the combination this bug
      // needs: long label text + a physically narrow device. Before the
      // fix (bare trailing `StatusSelector`, inner `Row` instead of `Wrap`)
      // this throws a `RenderFlex overflowed` FlutterError during pump.
      const ScheduledDose pending = ScheduledDose(
        medicationClientRecordId: 'm1',
        medicationName: 'A very long medication name that keeps going',
        doseMg: 75,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        status: ScheduledDoseStatus.pending,
        doseLog: null,
      );

      await pumpApp(
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
      // Same worst case as above, but for the `StatusChip` branch (a dose
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

      await pumpApp(
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
      // `Flexible` fix in DoseRow) as sufficient on its own.
      await pumpApp(
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
