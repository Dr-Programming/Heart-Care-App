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
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';
import '../widgets/medication_card.dart';
import '../widgets/missed_run_alert.dart';
import 'dose_history_screen.dart';
import 'medication_form_screen.dart';
import 'medication_search_screen.dart';

/// The "+" action's flow (M3 Figma rework, Decision E): search first, then
/// the form — reached via plain [Navigator] pushes, not named routes. Both
/// the FAB and the empty state's "add" action below call this so the two
/// entry points behave identically.
///
/// `outcome == null` means [MedicationSearchScreen] was backed out of
/// without a choice (see `MedicationSearchOutcome`'s doc comment for why
/// that is unambiguous) — nothing further happens, and the user is back on
/// this screen. Any non-null `outcome` means proceed to the form, pre-filled
/// from `outcome.entry` when a suggestion was tapped, or blank when "Enter
/// manually" was chosen instead.
Future<void> _startAddMedicationFlow(BuildContext context) async {
  final MedicationSearchOutcome? outcome = await Navigator.of(
    context,
  ).push<MedicationSearchOutcome>(
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
    final AsyncValue<MedicationListState> state = ref.watch(medicationListControllerProvider);

    return AppScaffold.banded(
      // Forces the AppBar into existence so the menu below can render — see
      // its doc comment on `actions`. Harmless in the real app: this screen
      // is a bottom-tab root there, so `Navigator.canPop()` is false and no
      // back chevron actually shows (AppScaffold gates the chevron on
      // `showBack && canPop`, not `showBack` alone).
      showBack: true,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text('meds.title'.tr(), style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormatter.displayDate(DateTime.now(), context.locale.languageCode),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      // Entry points to the existing, already-wired Adherence and Reminder
      // Settings routes (M3 Figma rework, Task 7) — no routing-table change,
      // just a UI path to destinations that previously had none from here.
      actions: <Widget>[
        PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'adherence') context.pushNamed(AppRoutes.adherence);
            if (value == 'reminders') context.pushNamed(AppRoutes.reminderSettings);
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
      // Stays visible across all three tabs (Today/Schedule/History) rather
      // than being scoped to one — it lives on the scaffold, not inside the
      // TabBarView, so switching tabs never affects it.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startAddMedicationFlow(context),
        icon: const Icon(Iconsax.add),
        label: Text('meds.add'.tr()),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(medicationListControllerProvider),
        ),
        data: (MedicationListState data) => _Content(state: data),
      ),
    );
  }
}

/// The screen body once medications have loaded: the Figma-matching
/// Today/Schedule/History segmented control (frame 368:2583) over a
/// `TabBarView`, or the full-screen empty state when there is nothing to
/// show tabs for at all.
///
/// `TabBarView` (over `IndexedStack`) is deliberate: each tab's built page is
/// kept alive by its default `addAutomaticKeepAlives` behaviour rather than
/// being torn down when scrolled off, so the History tab's active filter —
/// which actually lives in `doseHistoryControllerProvider`, not local widget
/// state — keeps its listener and survives switching tabs and back.
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

/// The pill-shaped segmented control from Figma frame 368:2583 — a rounded
/// track (`AppColors.surfaceAlt`) with a rounded selected-tab indicator
/// (`AppColors.primary`), built on Flutter's own `TabBar` rather than a
/// hand-rolled row of buttons so tab state, swipe-sync and a11y semantics
/// come for free from `DefaultTabController`.
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
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.ink,
          labelStyle: Theme.of(context).textTheme.titleSmall,
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
          tabs: <Widget>[
            Tab(text: 'meds.today'.tr()),
            Tab(text: 'meds.schedule'.tr()),
            Tab(text: 'meds.history.title'.tr()),
          ],
        ),
      ),
    );
  }
}

/// Today's doses — the screen's original today content, unchanged, now
/// living under the Today tab instead of stacked above the medication list.
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
          Text('meds.todayEmpty'.tr(), style: Theme.of(context).textTheme.bodyMedium)
        else
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
      ],
    );
  }
}

/// The medication list — the screen's original "your medications" content,
/// unchanged, now living under the Schedule tab.
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
        Text('meds.yourMedications'.tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final medication in state.medications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MedicationCard(
              medication: medication,
              onTap: () => context.pushNamed(
                AppRoutes.medicationEdit,
                pathParameters: <String, String>{'id': medication.clientRecordId},
              ),
            ),
          ),
      ],
    );
  }
}
