import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/eat_well.dart';

/// Heart-healthy eating with local foods: what to eat more of, what to limit.
/// Static content, so it works fully offline.
class EatWellScreen extends StatefulWidget {
  const EatWellScreen({super.key});

  @override
  State<EatWellScreen> createState() => _EatWellScreenState();
}

class _EatWellScreenState extends State<EatWellScreen> {
  String _tab = 'recommended';

  @override
  Widget build(BuildContext context) {
    final bool recommended = _tab == 'recommended';
    final List<FoodGroup> groups = recommended ? recommendedFoods : limitFoods;
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: BandHeader(
        title: 'education.eatWell.title'.tr(),
        subtitle: 'education.eatWell.subtitle'.tr(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: <Widget>[
          PillChoice(
            value: _tab,
            onChanged: (String v) => setState(() => _tab = v),
            options: <(String, String)>[
              ('recommended', 'education.eatWell.recommended'.tr()),
              ('limit', 'education.eatWell.limit'.tr()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            recommended
                ? 'education.eatWell.recommendedIntro'.tr()
                : 'education.eatWell.limitIntro'.tr(),
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final FoodGroup group in groups) ...<Widget>[
            _GroupCard(group: group, limit: !recommended),
            const SizedBox(height: AppSpacing.md),
          ],
          if (recommended) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const _PatternCard(),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'education.eatWell.footer'.tr(),
              style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.limit});

  final FoodGroup group;
  final bool limit;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color tint = limit ? AppColors.warningBg : AppColors.successBg;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Text(group.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(group.titleKey.tr(), style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(group.bodyKey.tr(), style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (group.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String item in group.items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      group.itemKey(item).tr(),
                      style: text.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'education.eatWell.patternTitle'.tr(),
            style: text.titleMedium?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < eatingPatternSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${i + 1}.', style: text.titleSmall),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'education.eatWell.pattern.${eatingPatternSteps[i]}'.tr(),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
