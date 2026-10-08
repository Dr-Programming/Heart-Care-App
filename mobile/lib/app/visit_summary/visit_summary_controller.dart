import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../../features/medication/domain/entities/adherence.dart';
import '../../features/medication/domain/repositories/medication_repository.dart';
import '../../features/medication/medication_providers.dart';
import '../../features/symptoms/domain/entities/symptom_check_in.dart';
import '../../features/symptoms/symptom_providers.dart';
import '../../features/vitals/domain/repositories/vitals_repository.dart';
import '../../features/vitals/vitals_providers.dart';
import 'visit_summary.dart';

/// Loads the visit summary from the phone's own records, so it works
/// offline and shows exactly what the patient logged.
class VisitSummaryController extends AsyncNotifier<VisitSummary> {
  int _windowDays = 7;

  int get windowDays => _windowDays;

  @override
  Future<VisitSummary> build() => _load(_windowDays);

  Future<void> setWindowDays(int days) async {
    _windowDays = days;
    state = const AsyncLoading<VisitSummary>();
    state = await AsyncValue.guard(() => _load(days));
  }

  Future<VisitSummary> _load(int windowDays) async {
    final VitalsRepository vitals = ref.read(vitalsRepositoryProvider);
    final MedicationRepository medications = ref.read(
      medicationRepositoryProvider,
    );
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateFormatter.daysAgo(
      windowDays - 1,
      from: now,
    );

    final List<SymptomCheckIn> checkIns =
        (await ref.read(symptomRepositoryProvider).history())
            .where(
              (SymptomCheckIn c) =>
                  !c.measuredAt.toLocal().isBefore(windowStart),
            )
            .toList();

    final List<bool?> daily = <bool?>[];
    for (int i = windowDays - 1; i >= 0; i--) {
      final DateTime day = DateFormatter.daysAgo(i, from: now);
      final DateTime endOfDay = i == 0
          ? now
          : DateTime(day.year, day.month, day.day, 23, 59, 59);
      final Adherence a = await medications.adherence(
        windowDays: 1,
        now: endOfDay,
      );
      daily.add(a.hasData ? a.taken >= a.due : null);
    }

    return VisitSummary.from(
      windowDays: windowDays,
      vitals: await vitals.history(from: windowStart, to: now),
      goals: await vitals.latestGoals(),
      adherence: await medications.adherence(windowDays: windowDays, now: now),
      previousAdherence: await medications.adherence(
        windowDays: windowDays,
        now: now.subtract(Duration(days: windowDays)),
      ),
      dailyAdherence: daily,
      checkIns: checkIns,
    );
  }
}

final AsyncNotifierProvider<VisitSummaryController, VisitSummary>
visitSummaryControllerProvider =
    AsyncNotifierProvider.autoDispose<VisitSummaryController, VisitSummary>(
      VisitSummaryController.new,
    );
