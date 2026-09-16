import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_block.dart';
import 'category_range_chart.dart';
import 'stat_bar_chart.dart';

class BlockRenderer extends StatelessWidget {
  const BlockRenderer({
    required this.block,
    this.accent = AppColors.accent,
    super.key,
  });

  final ContentBlock block;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return switch (block) {
      ParagraphBlock(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
      ),
      BulletListBlock(:final items) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.only(
                        top: 7,
                        right: AppSpacing.sm,
                      ),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: text.bodyLarge?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      CalloutBlock(:final style, :final text) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: style == CalloutStyle.warning
              ? AppColors.warningBg
              : AppColors.accentBg,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border(
            left: BorderSide(
              color: style == CalloutStyle.warning
                  ? AppColors.warning
                  : AppColors.accent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              style == CalloutStyle.warning
                  ? Iconsax.warning_2
                  : Iconsax.info_circle,
              color: style == CalloutStyle.warning
                  ? AppColors.warning
                  : AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
      ReferenceLinkBlock(:final label, :final url, :final kind) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.accentBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        kind == ReferenceKind.video
                            ? Iconsax.video_play
                            : Iconsax.document_text,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(label, style: text.titleSmall)),
                    const Icon(Iconsax.export_3, size: 16),
                  ],
                ),
                if (kind == ReferenceKind.video) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'education.videoCaptionTip'.tr(),
                    style: text.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      final CategoryRangesChartBlock chart => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: CategoryRangeChart(chart: chart),
      ),
      final BarChartBlock chart => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: StatBarChart(chart: chart),
      ),
    };
  }
}
