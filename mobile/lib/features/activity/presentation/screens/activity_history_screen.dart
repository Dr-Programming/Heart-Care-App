import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/usecases/weekly_activity_totals.dart';
import '../providers/activity_providers.dart';

/// FR-ACT-006 — reverse-chronological activity history with a weekly total.
class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime weekStart = DateFormatter.daysAgo(6);
    final AsyncValue<List<ActivitySession>> history = ref.watch(
      activityHistoryProvider(),
    );
    final AsyncValue<List<ActivitySession>> weekSessions = ref.watch(
      activityHistoryProvider(from: weekStart),
    );

    return AppScaffold(
      title: 'activity.history.title'.tr(),
      body: history.when(
        data: (List<ActivitySession> sessions) => _History(
          sessions: sessions,
          totals: weekSessions.maybeWhen(
            data: weeklyActivityTotals,
            orElse: () => const ActivityWeekTotals(
              sessionCount: 0,
              totalMinutes: 0,
              totalSteps: 0,
              totalDistanceMeters: 0,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.sessions, required this.totals});

  final List<ActivitySession> sessions;
  final ActivityWeekTotals totals;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.directions_walk_rounded,
        title: 'activity.history.emptyTitle'.tr(),
        message: 'activity.history.emptyBody'.tr(),
      );
    }

    final String localeCode = context.locale.languageCode;

    return ListView(
      children: <Widget>[
        SectionCard(
          title: 'activity.history.thisWeek'.tr(),
          child: Text(
            'activity.history.weekSummary'.tr(
              namedArgs: <String, String>{
                'sessions': '${totals.sessionCount}',
                'minutes': '${totals.totalMinutes}',
              },
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final ActivitySession session in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SectionCard(
              child: MetricTile(
                label: 'activity.type.${session.type.wire.toLowerCase()}'.tr(),
                value: '${session.durationMinutes}',
                unit: 'activity.history.minutesUnit'.tr(),
                caption: DateFormatter.displayDate(
                  session.measuredAt,
                  localeCode,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
