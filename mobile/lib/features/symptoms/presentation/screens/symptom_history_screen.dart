import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart' show LocalSyncStatus;
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../providers/symptom_providers.dart';

/// FR-SYM-009 — reverse-chronological check-in history, with severity
/// visible at a glance and per-row sync state (M5 spec §3).
class SymptomHistoryScreen extends ConsumerWidget {
  const SymptomHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SymptomHistoryEntry>> history = ref.watch(
      symptomHistoryProvider(),
    );

    return AppScaffold(
      title: 'symptoms.history.title'.tr(),
      body: history.when(
        data: (List<SymptomHistoryEntry> entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'symptoms.history.emptyTitle'.tr(),
              message: 'symptoms.history.emptyBody'.tr(),
            );
          }
          final String localeCode = context.locale.languageCode;
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final SymptomHistoryEntry entry = entries[index];
              return _HistoryRow(
                entry: entry,
                localeCode: localeCode,
                onTap: () => _showDetail(context, entry, localeCode),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    SymptomHistoryEntry entry,
    String localeCode,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _DetailSheet(entry: entry, localeCode: localeCode),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.localeCode,
    required this.onTap,
  });

  final SymptomHistoryEntry entry;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DateFormatter.displayDateTime(
                    entry.checkIn.measuredAt,
                    localeCode,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                _SyncStatusLabel(clientRecordId: entry.clientRecordId),
              ],
            ),
          ),
          StatusChip(severity: entry.overallSeverity),
        ],
      ),
    );
  }
}

class _SyncStatusLabel extends ConsumerWidget {
  const _SyncStatusLabel({required this.clientRecordId});

  final String clientRecordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LocalSyncStatus?> status = ref.watch(
      symptomSyncStatusProvider(clientRecordId),
    );
    final String label = status.maybeWhen(
      data: (LocalSyncStatus? s) => switch (s) {
        LocalSyncStatus.synced => 'symptoms.history.syncSynced'.tr(),
        LocalSyncStatus.conflict ||
        LocalSyncStatus.rejected => 'symptoms.history.syncIssue'.tr(),
        LocalSyncStatus.pending ||
        LocalSyncStatus.syncing ||
        null => 'symptoms.history.syncPending'.tr(),
      },
      orElse: () => 'symptoms.history.syncPending'.tr(),
    );
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: AppColors.textTertiary),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.entry, required this.localeCode});

  final SymptomHistoryEntry entry;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final checkIn = entry.checkIn;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'symptoms.history.detailTitle'.tr(),
                    style: text.titleLarge,
                  ),
                ),
                StatusChip(severity: entry.overallSeverity),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DateFormatter.displayDateTime(checkIn.measuredAt, localeCode),
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailLine(
              label: 'symptoms.checkIn.chestPain'.tr(),
              value: checkIn.chestPain.present
                  ? '${'symptoms.common.yes'.tr()} (${checkIn.chestPain.severity})'
                  : 'symptoms.common.no'.tr(),
            ),
            _DetailLine(
              label: 'symptoms.checkIn.breathlessness'.tr(),
              value:
                  'symptoms.checkIn.breathlessnessOption.${checkIn.shortnessOfBreath.wire.toLowerCase()}'
                      .tr(),
            ),
            _DetailLine(
              label: 'symptoms.checkIn.heartRate'.tr(),
              value: '${checkIn.heartRate}',
            ),
            _DetailLine(
              label:
                  '${'symptoms.checkIn.systolic'.tr()}/${'symptoms.checkIn.diastolic'.tr()}',
              value:
                  '${checkIn.bloodPressure.systolic}/${checkIn.bloodPressure.diastolic}',
            ),
            _DetailLine(
              label: 'symptoms.checkIn.swelling'.tr(),
              value: checkIn.swelling
                  ? 'symptoms.common.yes'.tr()
                  : 'symptoms.common.no'.tr(),
            ),
            _DetailLine(
              label: 'symptoms.checkIn.energyLevel'.tr(),
              value: '${checkIn.energyLevel}',
            ),
            if (checkIn.note != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(checkIn.note!, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(
            value,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
