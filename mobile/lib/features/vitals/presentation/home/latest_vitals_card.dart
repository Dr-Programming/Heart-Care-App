import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/shell/home_card.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';

/// FR-DASH-002/003/004. Order 200 — the "latest readings" band
/// (`core/shell/home_card.dart`'s documented convention).
const HomeCard latestVitalsCard = HomeCard(
  id: 'vitals-latest',
  order: 200,
  builder: _build,
);

Widget _build(BuildContext context) => const _LatestVitalsCardContent();

class _LatestVitalsCardContent extends ConsumerWidget {
  const _LatestVitalsCardContent();

  static const List<VitalType> _shown = <VitalType>[
    VitalType.bloodPressure,
    VitalType.weight,
    VitalType.glucose,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VitalsListState> state = ref.watch(vitalsListProvider);

    return SectionCard(
      title: 'vitals.homeCardTitle'.tr(),
      action: AppButton(
        label: 'common.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.goNamed(AppRoutes.vitals),
      ),
      child: state.maybeWhen(
        data: (VitalsListState data) => Column(
          children: <Widget>[
            for (final VitalType type in _shown)
              _Row(type: type, reading: data.latestByType[type]),
          ],
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.type, required this.reading});

  final VitalType type;
  final VitalReading? reading;

  @override
  Widget build(BuildContext context) {
    final VitalDescriptor descriptor = vitalDescriptors[type]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MetricTile(
        label: descriptor.labelKey.tr(),
        value: reading == null ? 'common.noValue'.tr() : _formatValue(reading!),
        unit: reading == null ? null : descriptor.unit,
        trailing: reading == null
            ? null
            : StatusChip.flagged(flagged: reading!.flagged),
      ),
    );
  }

  String _formatValue(VitalReading r) => switch (type) {
    VitalType.bloodPressure =>
      '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
    VitalType.weight =>
      r.bmi == null
          ? r.values['weight']!.toStringAsFixed(1)
          : '${r.values['weight']!.toStringAsFixed(1)} (BMI ${r.bmi!.toStringAsFixed(1)})',
    VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
    VitalType.heartRate || VitalType.cholesterol => '',
  };
}
