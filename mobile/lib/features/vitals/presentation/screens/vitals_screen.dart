import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';
import '../widgets/sparkline.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VitalsListState> state = ref.watch(vitalsListProvider);

    return AppScaffold(
      title: 'vitals.tabTitle'.tr(),
      showBack: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goNamed(AppRoutes.vitalsLog),
        child: const Icon(Icons.add),
      ),
      scrollable: true,
      body: state.maybeWhen(
        data: (VitalsListState data) => _Loaded(data: data),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.data});

  final VitalsListState data;

  @override
  Widget build(BuildContext context) {
    final bool anyReadings = data.latestByType.values.any(
      (VitalReading? r) => r != null,
    );

    if (!anyReadings) {
      return EmptyState(
        icon: Icons.favorite_outline,
        title: 'vitals.emptyTitle'.tr(),
        message: 'vitals.emptyBody'.tr(),
        actionLabel: 'vitals.logAction'.tr(),
        onAction: () => context.goNamed(AppRoutes.vitalsLog),
      );
    }

    return Column(
      children: <Widget>[
        for (final VitalType type in VitalType.values)
          _VitalTile(
            type: type,
            reading: data.latestByType[type],
            sparkline: data.sparklineByType[type] ?? const <VitalPoint>[],
          ),
        const SizedBox(height: 8),
        AppButton(
          label: 'vitals.viewHistory'.tr(),
          variant: AppButtonVariant.text,
          onPressed: () => context.goNamed(AppRoutes.vitalsHistory),
        ),
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.type,
    required this.reading,
    required this.sparkline,
  });

  final VitalType type;
  final VitalReading? reading;
  final List<VitalPoint> sparkline;

  @override
  Widget build(BuildContext context) {
    final VitalDescriptor descriptor = vitalDescriptors[type]!;

    return SectionCard(
      onTap: () => context.goNamed(
        AppRoutes.vitalsTrend,
        pathParameters: <String, String>{'type': type.wire},
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MetricTile(
              label: descriptor.labelKey.tr(),
              value: reading == null
                  ? 'common.noValue'.tr()
                  : _formatValue(type, reading!),
              unit: reading == null ? null : descriptor.unit,
              trailing: reading == null
                  ? null
                  : StatusChip.flagged(flagged: reading!.flagged),
            ),
          ),
          if (sparkline.length >= 2)
            SizedBox(
              width: 64,
              child: Sparkline(points: sparkline, color: AppColors.accent),
            ),
        ],
      ),
    );
  }

  String _formatValue(VitalType type, VitalReading r) => switch (type) {
    VitalType.bloodPressure =>
      '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
    VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
    VitalType.heartRate => r.values['heartRate']!.toStringAsFixed(0),
    VitalType.weight => r.values['weight']!.toStringAsFixed(1),
    VitalType.cholesterol => r.values['total']!.toStringAsFixed(1),
  };
}
