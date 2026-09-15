import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cards.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';

HomeCard latestVitalsHomeCard() {
  return const HomeCard(
    id: 'vitals-latest',
    order: 200,
    builder: _LatestVitalsCard.build,
  );
}

abstract final class _LatestVitalsCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerWidget {
  const _Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<VitalType, VitalReading?>> state = ref.watch(
      vitalsListControllerProvider,
    );

    return AccentCard(
      accent: AppColors.accent,
      icon: Iconsax.activity,
      title: 'vitals.home.title'.tr(),
      action: AppButton(
        label: 'vitals.home.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.goNamed(AppRoutes.vitals),
      ),
      child: state.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object _, StackTrace _) => Text('vitals.home.noReading'.tr()),
        data: (Map<VitalType, VitalReading?> latest) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final VitalType type in <VitalType>[
              VitalType.bloodPressure,
              VitalType.weight,
              VitalType.glucose,
            ])
              MetricTile(
                label: vitalDescriptors[type]!.labelKey.tr(),
                value: _valueText(latest[type], type),
              ),
          ],
        ),
      ),
    );
  }

  String _valueText(VitalReading? reading, VitalType type) {
    if (reading == null) return '—';
    switch (type) {
      case VitalType.bloodPressure:
        return '${reading.values['systolic']!.toStringAsFixed(0)}/${reading.values['diastolic']!.toStringAsFixed(0)}';
      case VitalType.weight:
        final String bmiPart = reading.bmi == null
            ? ''
            : ' (BMI ${reading.bmi!.toStringAsFixed(1)})';
        return '${reading.values['weight']!.toStringAsFixed(1)}$bmiPart';
      case VitalType.glucose:
        return reading.values['glucose']!.toStringAsFixed(1);
      case VitalType.heartRate:
      case VitalType.cholesterol:
        return '—';
    }
  }
}
