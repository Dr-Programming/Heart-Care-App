import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../controllers/check_in_hub_controller.dart';

HomeCard checkInHomeCard() =>
    const HomeCard(id: 'check-in', order: 150, builder: _CheckInCard.build);

abstract final class _CheckInCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerWidget {
  const _Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomCheckIn?> state = ref.watch(
      checkInHubControllerProvider,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return AccentCard(
      accent: AppColors.success,
      icon: Iconsax.clipboard_text,
      title: 'symptoms.tabTitle'.tr(),
      action: AppButton(
        label: 'common.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.goNamed(AppRoutes.checkIn),
      ),
      child: state.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object _, StackTrace _) =>
            Text('common.noValue'.tr(), style: text.bodyMedium),
        data: (SymptomCheckIn? today) => today == null
            ? Text('symptoms.hub.notDoneShort'.tr(), style: text.bodyMedium)
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      actionKeyFor(today.overall).tr(),
                      style: text.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(severity: today.overall),
                ],
              ),
      ),
    );
  }
}
