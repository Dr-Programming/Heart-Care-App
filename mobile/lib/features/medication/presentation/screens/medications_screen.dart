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
      // No separate AppBar: this screen is a bottom-tab root, so it never
      // has anything to pop back to, and Figma's own header band never
      // draws one above itself. An earlier task forced one into existence
      // (`showBack: true`) purely to host the overflow menu below — that
      // added a real, mostly-empty system AppBar strip on top of the
      // band, taller than Figma's design. The menu now lives inside the
      // band itself instead (see the top-right `PopupMenuButton` in
      // `bandChild`), so no AppBar is needed at all.
      //
      // `showBack` genuinely has to be passed as `false` here, not just
      // omitted: `AppScaffold.banded`'s own default is `showBack = true`,
      // and its `appBar:` is only actually `null` when
      // `title == null && !showBack`. The very first version of this fix
      // removed the explicit `showBack: true` and the old `actions:` list,
      // but never added `showBack: false` — so the AppBar kept silently
      // defaulting to existing (with no title/actions, so nothing visibly
      // *in* it, but still real height, tinted `AppColors.headerBand`,
      // stacked above the band and the offline-sync banner). That
      // leftover AppBar — not the band itself — was the actual header
      // still reading as oversized on a real device after that fix.
      showBack: false,
      //
      // Overrides the default `AppSpacing.headerBandHeight` (215) — that
      // value doesn't actually match this screen's own Figma frames at all:
      // both Screen 6.0 and Screen 6.4's own header-band background vectors
      // are ~128-139px tall on Figma's 402x874 canvas, not 215 (215 is
      // presumably tuned for a taller header elsewhere in the app, outside
      // this feature). 150 sits close to that real range while still
      // leaving room for a genuinely accessible ~48dp tap target on the
      // menu icon this band also now carries (Figma's own mockup icon is a
      // small static image with no real tap-target reservation at all — a
      // fully clickable version needs a little more room than the flat
      // design implies, confirmed by an actual overflow at this feature's
      // narrow-width test viewports before this value was tuned). A local
      // override here, not a change to the shared `AppSpacing.headerBandHeight`
      // token, which every other screen across the app (outside this
      // feature's scope) also uses.
      bandHeight: 150,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // Entry points to the existing, already-wired Adherence and
              // Reminder Settings routes (M3 Figma rework, Task 7) — no
              // routing-table change, just a UI path to destinations that
              // previously had none from here.
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.ink),
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
          ),
          const Spacer(),
          Text('meds.title'.tr(), style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormatter.displayDate(DateTime.now(), context.locale.languageCode),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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
/// (`AppColors.ink` — Figma reserves `AppColors.primary`/orange for primary
/// action buttons only, never a selected-tab/chip fill; see
/// `_FrequencyChip` in medication_form_screen.dart for the same convention),
/// built on Flutter's own `TabBar` rather than a hand-rolled row of buttons
/// so tab state, swipe-sync and a11y semantics come for free from
/// `DefaultTabController`.
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
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.ink,
          labelStyle: Theme.of(context).textTheme.titleSmall,
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
          // Equal-width tabs (`isScrollable: false`, the default) divide the
          // available width three ways regardless of label length — "Dose
          // history" (this tab's page-title copy, reused here) and even
          // plain "Schedule" were genuinely being clipped mid-word on a real
          // device at `titleSmall` size. Figma's own tab literally just says
          // "History" (not "Dose history" — that longer copy is only
          // appropriate for the full standalone page, kept as
          // `meds.history.title` for that), so `meds.historyTab` matches it
          // exactly. Wrapping every label in `FittedBox` on top of that is a
          // second, independent guard: whatever the copy (including
          // Amharic's typically-longer strings), it shrinks to fit its own
          // third of the bar instead of ever clipping again.
          tabs: <Widget>[
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('meds.today'.tr()))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('meds.schedule'.tr()))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('meds.historyTab'.tr()))),
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
