import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';
import '../widgets/medication_card.dart';
import '../widgets/missed_run_alert.dart';
import 'dose_history_screen.dart';
import 'medication_form_screen.dart';
import 'medication_search_screen.dart';

Future<void> _startAddMedicationFlow(BuildContext context) async {
  final MedicationSearchOutcome? outcome = await Navigator.of(context)
      .push<MedicationSearchOutcome>(
        MaterialPageRoute<MedicationSearchOutcome>(
          builder: (_) => const MedicationSearchScreen(),
        ),
      );
  if (outcome == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MedicationFormScreen(prefillEntry: outcome.entry),
    ),
  );
}

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> state = ref.watch(
      medicationListControllerProvider,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      actions: <Widget>[
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, color: AppColors.ink),
          onSelected: (String value) {
            if (value == 'adherence') {
              context.pushNamed(AppRoutes.adherence);
            }
            if (value == 'reminders') {
              context.pushNamed(AppRoutes.reminderSettings);
            }
          },
          itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'adherence',
              child: Text('meds.adherence.title'.tr()),
            ),
            PopupMenuItem<String>(
              value: 'reminders',
              child: Text('meds.reminders.title'.tr()),
            ),
          ],
        ),
      ],
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('meds.title'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormatter.displayDate(
              DateTime.now(),
              context.locale.languageCode,
            ),
            style: text.bodyMedium,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startAddMedicationFlow(context),
        icon: const Icon(Iconsax.add),
        label: Text('meds.add'.tr()),
      ),

      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => ErrorView(
            failure: error is Failure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(medicationListControllerProvider),
          ),
          data: (MedicationListState data) => _Content(state: data),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final MedicationListState state;

  @override
  Widget build(BuildContext context) {
    if (state.medications.isEmpty) {
      return EmptyState(
        icon: Iconsax.health,
        title: 'meds.emptyTitle'.tr(),
        message: 'meds.emptyBody'.tr(),
        actionLabel: 'meds.add'.tr(),
        onAction: () => _startAddMedicationFlow(context),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _MedicationsTabBar(),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _TodayTab(state: state),
                _ScheduleTab(state: state),
                const DoseHistoryContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationsTabBar extends StatelessWidget {
  const _MedicationsTabBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,

          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          indicator: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.ink,

          labelStyle: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontSize: 13),
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontSize: 13),

          tabs: <Widget>[
            Tab(
              child: Text(
                'meds.today'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            Tab(
              child: Text(
                'meds.schedule'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            Tab(
              child: Text(
                'meds.historyTab'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab({required this.state});

  final MedicationListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (state.hasMissedRunAlert) ...<Widget>[
          MissedRunAlert(medications: state.missedRunAlerts),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('meds.today'.tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (state.todaysDoses.isEmpty)
          Text(
            'meds.todayEmpty'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...<Widget>[
          for (final dose in state.todaysDoses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SectionCard(
                child: DoseRow(
                  dose: dose,
                  onLog: (DoseStatus status, {String? note}) => ref
                      .read(medicationListControllerProvider.notifier)
                      .logDose(
                        medicationClientRecordId: dose.medicationClientRecordId,
                        status: status,
                        scheduledDate: dose.scheduledDate,
                        scheduledTime: dose.scheduledTime,
                        note: note,
                      ),
                ),
              ),
            ),

          if (_nextPendingDose(state.todaysDoses) case final ScheduledDose next)
            _NextReminderBanner(dose: next),
        ],
      ],
    );
  }
}

ScheduledDose? _nextPendingDose(List<ScheduledDose> doses) {
  for (final ScheduledDose dose in doses) {
    if (dose.status == ScheduledDoseStatus.pending) return dose;
  }
  return null;
}

class _NextReminderBanner extends StatelessWidget {
  const _NextReminderBanner({required this.dose});

  final ScheduledDose dose;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = dose.scheduledTime.split(':');
    final DateTime now = DateTime.now();
    final DateTime due = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final Duration remaining = due.difference(now);
    final int hours = remaining.inHours;
    final int minutes = remaining.inMinutes.remainder(60);
    final String duration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final String doseLabel = dose.doseMg == dose.doseMg.roundToDouble()
        ? dose.doseMg.toStringAsFixed(0)
        : dose.doseMg.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Iconsax.notification, color: AppColors.accent, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'meds.nextReminder'.tr(
                namedArgs: <String, String>{
                  'duration': duration,
                  'name': '${dose.medicationName} $doseLabel mg',
                },
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.state});

  final MedicationListState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          'meds.yourMedications'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final medication in state.medications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MedicationCard(
              medication: medication,
              onTap: () => context.pushNamed(
                AppRoutes.medicationEdit,
                pathParameters: <String, String>{
                  'id': medication.clientRecordId,
                },
              ),
            ),
          ),
      ],
    );
  }
}
