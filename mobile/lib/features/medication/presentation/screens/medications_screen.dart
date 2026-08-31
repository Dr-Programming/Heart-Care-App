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

/// The "+" action's flow: search first, then the form — reached via plain
/// [Navigator] pushes, not named routes. Both the FAB and the empty state's
/// "add" action below call this so the two entry points behave identically.
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
      // has anything to pop back to, and the design's own header band never
      // draws one above itself. The overflow menu lives inside the band
      // itself instead (see the top-right `PopupMenuButton` in
      // `bandChild`), so no AppBar is needed at all.
      //
      // `showBack` has to be passed as `false` here, not just omitted:
      // `AppScaffold.banded`'s own default is `showBack = true`, and its
      // `appBar:` is only actually `null` when `title == null && !showBack`.
      // Omitting it silently leaves a real, mostly-empty AppBar rendered
      // above the band (no title/actions visible in it, but still tinted
      // `AppColors.headerBand` and taking up height) — an easy trap since
      // nothing visibly appears wrong until measured against the design.
      showBack: false,
      //
      // Overrides the default `AppSpacing.headerBandHeight` (215) — that
      // value doesn't match this screen's own design frame: frame 368:2846's
      // header-band background vector spans y=0.11% to 83.98% of an 874px
      // canvas, i.e. ~139px. Even that measured figure left visible empty
      // space at the top of the band once built, because the `Spacer()`
      // this band used to push title+subtitle to the bottom — on top of the
      // `PopupMenuButton`'s own default ~48dp Material tap target above it —
      // ate into that height with nothing to show for it. Both are fixed
      // below (a fixed small gap instead of `Spacer`, and the menu icon's
      // tap target tightened to match the back-arrow icons on this
      // feature's other three screens), so this height now matches the
      // band's own natural content size. A local override here, not a
      // change to the shared `AppSpacing.headerBandHeight` token, which
      // every other screen across the app also uses.
      bandHeight: 112, // the band's own natural content height
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // Entry points to the Adherence and Reminder Settings routes —
              // no routing-table change, just a UI path to destinations
              // that otherwise have no way in from here.
              //
              // `padding: zero` + tight `constraints`, matching the
              // back-arrow icons on this feature's other three screens
              // (see e.g. `MedicationSearchScreen`'s bandChild) — the
              // default Material `IconButton` this wraps otherwise reserves
              // a full ~48dp tap target, wasting space in a compact band.
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
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
          const SizedBox(height: AppSpacing.xs),
          // FittedBox, not a bare Text: guards this fixed-height band
          // against a title long enough to wrap to a second line (see
          // `ReviewMedicationScreen`'s matching comment) at any translation
          // length, not just today's English/Amharic copy.
          //
          // fontSize 28, not bare `headlineLarge` (24) — reads better once
          // the band itself is compact. The `FittedBox` above still shrinks
          // it back down whenever 28 doesn't fit (a long name, a narrow
          // device, Amharic), so this is a floor the title grows to fill,
          // not a value that can itself cause an overflow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'meds.title'.tr(),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // `bodyMedium` alone renders AppColors.textSecondary (its
          // default) — design frame 368:2846 has this date line at #282a2a
          // (ink), not grey.
          Text(
            DateFormatter.displayDate(DateTime.now(), context.locale.languageCode),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
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
      // the design leaves a real gap (~24px) between the band and whatever comes
      // next, rather than butting content flush against it — `AppScaffold`
      // itself doesn't add one (its body starts right after the band), so
      // each banded screen in this feature adds its own, matching the real
      // spacing token closest to that measured gap.
      body: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => ErrorView(
            failure: error is Failure ? error : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(medicationListControllerProvider),
          ),
          data: (MedicationListState data) => _Content(state: data),
        ),
      ),
    );
  }
}

/// The screen body once medications have loaded: the design-matching
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

/// The pill-shaped segmented control from design frame 368:2583 — a rounded
/// track (`AppColors.surfaceAlt`) with a rounded selected-tab indicator
/// (`AppColors.ink` — the design reserves `AppColors.primary`/orange for primary
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
          // `Tab`'s own default `labelPadding` reserves 16dp on each side of
          // every label (`kTabLabelPadding`) — 32dp per tab, 96dp total
          // across all three, which was most of why "Schedule" had so
          // little room to work with in the first place. `xs` (4dp) each
          // side reclaims nearly all of that back into actual label width.
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          indicator: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.ink,
          // Explicit fontSize, not bare `titleSmall`: at `titleSmall`'s own
          // size, "Schedule" — the widest of the three labels — needs its
          // own shrink-to-fit treatment to avoid clipping, which would make
          // it render smaller than "Today"/"History" if each label were
          // left to size itself independently. 13, not `titleSmall`'s own
          // 14 — reclaiming `Tab`'s own default padding above (see
          // `labelPadding`) freed up enough width that all three fit
          // comfortably at a size close to, but safely under, that default.
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
          // Equal-width tabs (`isScrollable: false`, the default) divide the
          // available width three ways regardless of label length — "Dose
          // history" (this tab's page-title copy, reused here) and even
          // plain "Schedule" would clip mid-word without the fixes above.
          // the design's own tab literally just says "History" (not "Dose
          // history" — that longer copy is only appropriate for the full
          // standalone page, kept as `meds.history.title` for that), so
          // `meds.historyTab` matches it exactly.
          //
          // No per-label `FittedBox`, deliberately: an independent
          // shrink-to-fit on each label means whichever one needs *any*
          // shrinking renders smaller than its neighbours that don't —
          // inconsistent sizing across the three tabs. `overflow: ellipsis`
          // instead guarantees the same fixed size on all three always;
          // combined with `labelPadding` reclaiming the width `Tab` wastes
          // by default, none of the three (including "Schedule") should
          // ever actually need to ellipsize on a real device, but if a
          // translation is long enough to force it, truncating beats
          // silently resizing just that one tab.
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
          // design frame 368:2846 shows a "Next reminder in Xh Ym — <name>"
          // line in accent blue right after today's dose rows.
          // `_nextPendingDose` reuses `todaysDoses`' own sort order
          // (ascending scheduledTime, guaranteed by `scheduledDosesFor`)
          // rather than re-sorting.
          if (_nextPendingDose(state.todaysDoses) case final ScheduledDose next)
            _NextReminderBanner(dose: next),
        ],
      ],
    );
  }
}

/// The earliest dose in [doses] still ahead of now today, or null when
/// nothing is left to remind about (every dose today is logged/overdue, or
/// there are no doses at all). `doses` is already sorted ascending by
/// `scheduledTime` (see `scheduledDosesFor`), so the first `pending` entry
/// — pending meaning strictly not-yet-due, per `ScheduledDoseStatus`'s own
/// doc comment — is the next one, with no re-sort needed here.
ScheduledDose? _nextPendingDose(List<ScheduledDose> doses) {
  for (final ScheduledDose dose in doses) {
    if (dose.status == ScheduledDoseStatus.pending) return dose;
  }
  return null;
}

/// "Next reminder in 6h 22m — Metoprolol 50 mg" (frame 368:2846) — a
/// standing, non-dismissible heads-up under today's dose list, not a
/// per-dose element, so it lives once beneath the whole list rather than on
/// [DoseRow] itself.
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
    // Same dose-mg formatting already duplicated in DoseRow/MedicationCard/
    // MedicationSearchScreen's suggestion card ("50" not "50.0") — kept
    // local here rather than extracted, matching how those three do it.
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
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
