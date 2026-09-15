import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> online = ref.watch(onlineStatusProvider);
    final int pending = ref.watch(pendingSyncCountProvider).value ?? 0;

    if (online.value ?? true) {
      return pending > 0
          ? _Strip(
              icon: Icons.cloud_upload_outlined,
              text: 'sync.pending'.tr(
                namedArgs: <String, String>{'count': '$pending'},
              ),
              background: AppColors.accentBg,
              foreground: AppColors.accent,
            )
          : const SizedBox.shrink();
    }

    return _Strip(
      icon: Icons.wifi_off_rounded,
      text: pending > 0
          ? 'sync.offlineWithPending'.tr(
              namedArgs: <String, String>{'count': '$pending'},
            )
          : 'sync.offline'.tr(),
      background: AppColors.warningBg,
      foreground: AppColors.warning,
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

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
        ],
      ),
    );
  }
}
