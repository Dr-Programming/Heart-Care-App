import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/clinical/alert_evaluator.dart';
// Hidden for the same reason as everywhere else in this feature: the Drift
// row classes share their names with the domain entities. Only
// `LocalSyncStatus` is needed from here.
import '../../../../core/db/app_database.dart' hide DoseLog, Medication;
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../controllers/dose_history_controller.dart';

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'meds.history.title'.tr(),
      body: const DoseHistoryContent(),
    );
  }
}

/// The dose-history list/filter/sync-status content, extracted so
/// MedicationsScreen's History tab (Task 7 of the Figma-fidelity plan) and
/// this screen's own route can share it without duplicating logic.
class DoseHistoryContent extends ConsumerWidget {
  const DoseHistoryContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DoseHistoryState> state = ref.watch(doseHistoryControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => ErrorView(
        failure: e is Failure ? e : UnknownFailure(e.toString()),
        onRetry: () => ref.invalidate(doseHistoryControllerProvider),
      ),
      data: (DoseHistoryState data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (data.medications.isNotEmpty) _FilterBar(state: data),
          Expanded(
            child: data.entries.isEmpty
                ? EmptyState(
                    icon: Iconsax.document,
                    title: 'meds.history.emptyTitle'.tr(),
                    message: 'meds.history.emptyBody'.tr(),
                  )
                : ListView.separated(
                    itemCount: data.entries.length,
                    separatorBuilder: (BuildContext _, int _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) =>
                        _HistoryRow(entry: data.entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Picks which medication's history to show (I5).
///
/// `DoseHistoryController.setFilter` existed from Task 15 with no UI caller at
/// all, so the whole history was always "everything, ever".
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state});

  final DoseHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selected = state.filter.medicationClientRecordId;

    void select(String? clientRecordId) {
      ref
          .read(doseHistoryControllerProvider.notifier)
          .setFilter(DoseHistoryFilter(medicationClientRecordId: clientRecordId));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            ChoiceChip(
              label: Text('meds.history.filterAll'.tr()),
              selected: selected == null,
              onSelected: (_) => select(null),
            ),
            for (final Medication medication in state.medications) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                label: Text(medication.name),
                selected: selected == medication.clientRecordId,
                onSelected: (_) => select(medication.clientRecordId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DoseHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DoseLog log = entry.log;
    final String? syncLabel = syncStatusLabel(entry.syncStatus);

    return SectionCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Which medication this log belongs to — the row used to show
                // only a date and a status, which is unreadable for a patient
                // on more than one medication (I5).
                Text(
                  entry.medicationName ?? 'common.noValue'.tr(),
                  style: text.titleMedium,
                ),
                Text(
                  '${log.scheduledDate} ${log.scheduledTime ?? ""}'.trim(),
                  style: text.bodySmall,
                ),
                if (log.note != null) Text(log.note!, style: text.bodySmall),
                if (syncLabel != null)
                  Text(syncLabel, style: text.bodySmall),
              ],
            ),
          ),
          StatusChip(
            severity: log.status == DoseStatus.taken ? Severity.none : Severity.monitor,
            label: 'meds.status.${log.status.name}'.tr(),
          ),
        ],
      ),
    );
  }
}

/// What to say about a record the server has not accepted yet, or refused.
///
/// Null means "nothing worth saying": either it is safely on the server, or
/// its queue entry is gone, which amounts to the same thing. Offline-first
/// means a pending record is normal, not an error — the wording says the
/// record is safe rather than that something went wrong.
String? syncStatusLabel(LocalSyncStatus? status) => switch (status) {
  null || LocalSyncStatus.synced => null,
  LocalSyncStatus.pending ||
  LocalSyncStatus.syncing => 'meds.history.syncPending'.tr(),
  LocalSyncStatus.conflict ||
  LocalSyncStatus.rejected => 'meds.history.syncRejected'.tr(),
};
