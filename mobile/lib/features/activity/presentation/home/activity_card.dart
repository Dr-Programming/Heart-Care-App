import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/usecases/weekly_activity_totals.dart';
import '../providers/activity_providers.dart';

/// Home card, order 210 (FR-DASH-001…009) — today's activity, or "—" when
/// nothing has been logged yet. Must never throw: a card that crashes takes
/// the whole dashboard down with it, so a stream error degrades to "—" the
/// same way an empty result does.
class ActivityHomeCard extends ConsumerWidget {
  const ActivityHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ActivitySession>> today = ref.watch(
      activityHistoryProvider(from: DateFormatter.startOfDay(DateTime.now())),
    );

    return SectionCard(
      title: 'activity.home.title'.tr(),
      child: today.when(
        data: (List<ActivitySession> sessions) {
          if (sessions.isEmpty) {
            return MetricTile(
              label: 'activity.home.today'.tr(),
              value: 'common.noValue'.tr(),
            );
          }
          final ActivityWeekTotals totals = weeklyActivityTotals(sessions);
          return MetricTile(
            label: 'activity.home.today'.tr(),
            value: '${totals.totalMinutes}',
            unit: 'activity.history.minutesUnit'.tr(),
            caption: 'activity.home.sessions'.tr(
              namedArgs: <String, String>{'count': '${totals.sessionCount}'},
            ),
          );
        },
        loading: () => MetricTile(
          label: 'activity.home.today'.tr(),
          value: 'common.loading'.tr(),
        ),
        error: (Object _, StackTrace _) => MetricTile(
          label: 'activity.home.today'.tr(),
          value: 'common.noValue'.tr(),
        ),
      ),
    );
  }
}
