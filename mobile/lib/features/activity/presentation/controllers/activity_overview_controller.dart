import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity_providers.dart';
import '../../domain/activity_summary.dart';
import '../../domain/entities/activity_entry.dart';

class ActivityOverview {
  const ActivityOverview({required this.summary, required this.entries});

  final ActivitySummary summary;

  /// Newest first.
  final List<ActivityEntry> entries;
}

class ActivityOverviewController extends AsyncNotifier<ActivityOverview> {
  @override
  Future<ActivityOverview> build() async {
    final List<ActivityEntry> entries = await ref
        .watch(activityRepositoryProvider)
        .history();
    return ActivityOverview(
      summary: ActivitySummary.of(entries),
      entries: entries,
    );
  }
}

final AsyncNotifierProvider<ActivityOverviewController, ActivityOverview>
activityOverviewControllerProvider =
    AsyncNotifierProvider<ActivityOverviewController, ActivityOverview>(
      ActivityOverviewController.new,
    );
