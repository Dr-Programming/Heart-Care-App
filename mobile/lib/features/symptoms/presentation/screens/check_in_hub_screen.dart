import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../providers/symptom_providers.dart';
import '../widgets/severity_result_banner.dart';

/// The `checkIn` tab root (M5 spec §3): today's check-in prompt or result,
/// plus entry points to the symptom form, activity logging and both
/// histories — the one tab M5 shares between its two verticals.
class CheckInHubScreen extends ConsumerWidget {
  const CheckInHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomHistoryEntry?> today = ref.watch(
      todayCheckInProvider,
    );

    return AppScaffold(
      title: 'symptoms.hub.title'.tr(),
      showBack: false,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          today.when(
            data: (SymptomHistoryEntry? entry) => entry == null
                ? _PromptCard(
                    onTap: () => context.goNamed(AppRoutes.symptomCheckIn),
                  )
                : _DoneCard(entry: entry),
            loading: () => const Center(child: CircularProgressIndicator()),
            // A card must never throw or block on the network — degrade to
            // the same prompt an offline/never-checked-in patient would see.
            error: (Object _, StackTrace _) => _PromptCard(
              onTap: () => context.goNamed(AppRoutes.symptomCheckIn),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: 'symptoms.hub.more'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _NavRow(
                  label: 'symptoms.hub.symptomHistory'.tr(),
                  icon: Icons.history_rounded,
                  onTap: () => context.goNamed(AppRoutes.symptomHistory),
                ),
                const Divider(height: AppSpacing.xl),
                _NavRow(
                  label: 'activity.log.title'.tr(),
                  icon: Icons.directions_walk_rounded,
                  onTap: () => context.goNamed(AppRoutes.activityLog),
                ),
                const Divider(height: AppSpacing.xl),
                _NavRow(
                  label: 'activity.history.title'.tr(),
                  icon: Icons.list_alt_rounded,
                  onTap: () => context.goNamed(AppRoutes.activityHistory),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'symptoms.hub.promptTitle'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'symptoms.hub.promptBody'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'symptoms.hub.startCheckIn'.tr(), onPressed: onTap),
        ],
      ),
    );
  }
}

/// Combines today's check-in with the missed-dose cross-signal
/// (FR-DEC-003) — whichever is more severe wins, since neither Home nor
/// this hub has a standalone Alerts screen to show them separately (design
/// decision 4).
class _DoneCard extends ConsumerWidget {
  const _DoneCard({required this.entry});

  final SymptomHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Severity> cross = ref.watch(crossSignalProvider);
    final Severity effective = cross.maybeWhen(
      data: (Severity s) => entry.overallSeverity.coalesce(s),
      orElse: () => entry.overallSeverity,
    );

    return SectionCard(
      title: 'symptoms.hub.doneTitle'.tr(),
      child: SeverityResultBanner(severity: effective),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
