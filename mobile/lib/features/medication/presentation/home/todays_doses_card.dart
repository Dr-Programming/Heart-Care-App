import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:iconsax/iconsax.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../medication_providers.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';
import '../widgets/missed_run_alert.dart';

HomeCard todaysDosesHomeCard() {
  return const HomeCard(
    id: 'meds-today',
    order: 100,
    builder: _TodaysDosesCard.build,
  );
}

abstract final class _TodaysDosesCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerStatefulWidget {
  const _Card();

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(medicationRemindersStartupProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MedicationListState> state = ref.watch(
      medicationListControllerProvider,
    );

    return state.when(
      loading: () => _shell(
        context,
        const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (Object _, StackTrace _) =>
          _shell(context, Text('common.noValue'.tr())),
      data: (MedicationListState data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (data.hasMissedRunAlert) ...<Widget>[
            MissedRunAlert(medications: data.missedRunAlerts),
            const SizedBox(height: AppSpacing.md),
          ],
          _shell(
            context,
            data.todaysDoses.isEmpty
                ? Text(
                    'meds.todayEmpty'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: <Widget>[
                      for (final dose in data.todaysDoses.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: DoseRow(
                            dose: dose,
                            onLog: (DoseStatus status, {String? note}) => ref
                                .read(medicationListControllerProvider.notifier)
                                .logDose(
                                  medicationClientRecordId:
                                      dose.medicationClientRecordId,
                                  status: status,
                                  scheduledDate: dose.scheduledDate,
                                  scheduledTime: dose.scheduledTime,
                                  note: note,
                                ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _shell(BuildContext context, Widget child) {
    return AccentCard(
      accent: AppColors.primary,
      icon: Iconsax.health,
      title: 'meds.today'.tr(),
      action: AppButton(
        label: 'common.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.pushNamed(AppRoutes.medications),
      ),
      child: child,
    );
  }
}
