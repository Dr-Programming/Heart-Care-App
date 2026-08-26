import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../controllers/dose_history_controller.dart';

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DoseLog>> logs = ref.watch(doseHistoryControllerProvider);

    return AppScaffold(
      title: 'meds.history.title'.tr(),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => ErrorView(
          failure: e is Failure ? e : UnknownFailure(e.toString()),
          onRetry: () => ref.invalidate(doseHistoryControllerProvider),
        ),
        data: (List<DoseLog> entries) => entries.isEmpty
            ? EmptyState(
                icon: Iconsax.document,
                title: 'meds.history.emptyTitle'.tr(),
                message: 'meds.history.emptyBody'.tr(),
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (BuildContext _, int _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final DoseLog log = entries[i];
                  return SectionCard(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${log.scheduledDate} ${log.scheduledTime ?? ""}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (log.note != null)
                                Text(log.note!, style: Theme.of(context).textTheme.bodySmall),
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
                },
              ),
      ),
    );
  }
}
