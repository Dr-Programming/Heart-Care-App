import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_history_controller.dart';
import '../widgets/reading_row.dart';

class VitalsHistoryScreen extends ConsumerWidget {
  const VitalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VitalReading>> state = ref.watch(
      vitalsHistoryControllerProvider,
    );
    final VitalsHistoryController controller = ref.read(
      vitalsHistoryControllerProvider.notifier,
    );

    return AppScaffold(
      title: 'vitals.history.title'.tr(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: DropdownButton<VitalType?>(
              value: controller.typeFilter,
              hint: Text('vitals.history.filterAll'.tr()),
              items: <DropdownMenuItem<VitalType?>>[
                DropdownMenuItem<VitalType?>(
                  value: null,
                  child: Text('vitals.history.filterAll'.tr()),
                ),
                for (final VitalType type in VitalType.values)
                  DropdownMenuItem<VitalType?>(
                    value: type,
                    child: Text(vitalDescriptors[type]!.labelKey.tr()),
                  ),
              ],
              onChanged: (VitalType? value) => controller.setTypeFilter(value),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace _) => ErrorView(
                failure: error is Failure ? error : UnknownFailure(error.toString()),
                onRetry: () => controller.setTypeFilter(controller.typeFilter),
              ),
              data: (List<VitalReading> readings) => readings.isEmpty
                  ? EmptyState(
                      icon: Iconsax.heart,
                      title: 'vitals.history.emptyTitle'.tr(),
                      message: 'vitals.history.emptyBody'.tr(),
                    )
                  : ListView.builder(
                      itemCount: readings.length,
                      itemBuilder: (BuildContext context, int index) => ReadingRow(
                        reading: readings[index],
                        localeCode: context.locale.languageCode,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
