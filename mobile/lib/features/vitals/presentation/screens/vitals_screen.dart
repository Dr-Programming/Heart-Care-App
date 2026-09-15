import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';
import '../widgets/vital_accent_card.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<VitalType, VitalReading?>> state = ref.watch(
      vitalsListControllerProvider,
    );

    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('vitals.tabTitle'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('vitals.tabSubtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.vitalsLog),
        icon: const Icon(Iconsax.add),
        label: Text('vitals.log.title'.tr()),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () =>
              ref.read(vitalsListControllerProvider.notifier).refresh(),
        ),
        data: (Map<VitalType, VitalReading?> latest) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: <Widget>[
            for (final VitalType type in VitalType.values)
              VitalAccentCard(
                accent: vitalAccents[type]!,
                onTap: () => context.pushNamed(
                  AppRoutes.vitalsTrend,
                  pathParameters: <String, String>{'type': type.wire},
                ),
                child: MetricTile(
                  label: vitalDescriptors[type]!.labelKey.tr(),
                  value: _latestValueText(latest[type], type),
                  icon: vitalDescriptors[type]!.icon,
                  iconColor: vitalAccents[type],
                  trailing: latest[type] == null
                      ? null
                      : StatusChip(
                          severity: severityForVital(
                            type: type.wire,
                            values: latest[type]!.values.cast<String, num?>(),
                            bmi: latest[type]!.bmi,
                          ),
                        ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: AppButton(
                label: 'vitals.history.title'.tr(),
                variant: AppButtonVariant.text,
                onPressed: () => context.pushNamed(AppRoutes.vitalsHistory),
              ),
            ),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }

  String _latestValueText(VitalReading? reading, VitalType type) {
    if (reading == null) return '—';
    switch (type) {
      case VitalType.bloodPressure:
        return '${reading.values['systolic']!.toStringAsFixed(0)}/${reading.values['diastolic']!.toStringAsFixed(0)}';
      case VitalType.glucose:
        return reading.values['glucose']!.toStringAsFixed(1);
      case VitalType.heartRate:
        return reading.values['heartRate']!.toStringAsFixed(0);
      case VitalType.weight:
        return reading.values['weight']!.toStringAsFixed(1);
      case VitalType.cholesterol:
        return reading.values['total']!.toStringAsFixed(1);
    }
  }
}
