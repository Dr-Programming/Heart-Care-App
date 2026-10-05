import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart' show SyncQueueEntry;
import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> online = ref.watch(onlineStatusProvider);
    final int pending = ref.watch(pendingSyncCountProvider).value ?? 0;
    final List<SyncQueueEntry> rejected =
        ref.watch(rejectedSyncProvider).value ?? const <SyncQueueEntry>[];

    if (rejected.isNotEmpty) {
      return _Strip(
        icon: Icons.error_outline_rounded,
        text: 'sync.rejected'.plural(rejected.length),
        background: AppColors.criticalBg,
        foreground: AppColors.critical,
        actionLabel: 'sync.rejectedDetails'.tr(),
        onAction: () => _showRejected(context, ref, rejected),
      );
    }

    if (online.value ?? true) {
      return pending > 0
          ? _Strip(
              icon: Icons.cloud_upload_outlined,
              text: 'sync.pending'.plural(pending),
              background: AppColors.accentBg,
              foreground: AppColors.accent,
            )
          : const SizedBox.shrink();
    }

    return _Strip(
      icon: Icons.wifi_off_rounded,
      text: pending > 0
          ? 'sync.offlineWithPending'.plural(pending)
          : 'sync.offline'.tr(),
      background: AppColors.warningBg,
      foreground: AppColors.warning,
    );
  }
}

Future<void> _showRejected(
  BuildContext context,
  WidgetRef ref,
  List<SyncQueueEntry> rejected,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) {
      final TextTheme text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('sync.rejectedTitle'.tr(), style: text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('sync.rejectedHint'.tr(), style: text.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final SyncQueueEntry entry in rejected)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.critical,
                        ),
                        title: Text('sync.entity.${entry.entityType}'.tr()),
                        subtitle: Text(entry.lastError ?? ''),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () async {
                  await ref.read(syncQueueDaoProvider).dismissRejected();
                  if (sheet.mounted) Navigator.of(sheet).pop();
                },
                child: Text('sync.dismiss'.tr()),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
