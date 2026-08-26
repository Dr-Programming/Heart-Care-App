import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../medication_providers.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';
import '../widgets/missed_run_alert.dart';

/// Today's doses, order 100 — the today's-actions band (`HomeCard.order`).
///
/// Per `core/shell/home_card.dart`'s contract, a Home card must render
/// something offline and must never throw. The controller only ever reads
/// local Drift data (never awaits the network — CONTRIBUTING.md §5/§8), so
/// `loading` is transient and `error` is reachable only from a genuine local
/// read failure; both branches still render a normal `SectionCard` rather
/// than letting anything propagate.
HomeCard todaysDosesHomeCard() {
  return const HomeCard(id: 'meds-today', order: 100, builder: _TodaysDosesCard.build);
}

abstract final class _TodaysDosesCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerStatefulWidget {
  const _Card();

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card> {
  @override
  void initState() {
    super.initState();
    // The app-start hook for reminders (C2 / Decision 4): Android clears
    // pending alarms on reboot and force-stop, so something has to
    // re-schedule them every launch. This card is mounted at app start
    // because Home is the shell's initial tab, which makes it this feature's
    // own equivalent of `AppShell`'s `syncServiceProvider` read — and it
    // keeps the bootstrap inside `lib/features/medication/` rather than
    // adding another edit to the shared `app_wiring.dart`.
    //
    // Reading a `Provider` runs its body once per container and caches it, so
    // remounting this card (a tab switch, a rebuild) does not re-run the
    // bootstrap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(medicationRemindersStartupProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MedicationListState> state = ref.watch(medicationListControllerProvider);

    return state.when(
      loading: () => const SectionCard(
        title: null,
        child: SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
      ),
      error: (Object _, StackTrace _) =>
          SectionCard(title: 'meds.today'.tr(), child: Text('common.noValue'.tr())),
      data: (MedicationListState data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Two consecutive misses (FR-DEC-002) surface on Home as well as on
          // the tab: Home is the screen the patient actually opens.
          if (data.hasMissedRunAlert) ...<Widget>[
            MissedRunAlert(medications: data.missedRunAlerts),
            const SizedBox(height: AppSpacing.md),
          ],
          _todayCard(context, data),
        ],
      ),
    );
  }

  Widget _todayCard(BuildContext context, MedicationListState data) {
    return SectionCard(
      title: 'meds.today'.tr(),
      action: AppButton(
        label: 'common.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.pushNamed(AppRoutes.medications),
      ),
      child: data.todaysDoses.isEmpty
          ? Text('meds.todayEmpty'.tr(), style: Theme.of(context).textTheme.bodyMedium)
          : Column(
              children: <Widget>[
                for (final dose in data.todaysDoses.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: DoseRow(
                      dose: dose,
                      onLog: (DoseStatus status) => ref
                          .read(medicationListControllerProvider.notifier)
                          .logDose(
                            medicationClientRecordId: dose.medicationClientRecordId,
                            status: status,
                            scheduledDate: dose.scheduledDate,
                            scheduledTime: dose.scheduledTime,
                          ),
                    ),
                  ),
              ],
            ),
    );
  }
}
