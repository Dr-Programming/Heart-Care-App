import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/usecases/watch_history.dart';
import '../../domain/vital_descriptors.dart';
import '../../vitals_providers.dart';
import '../widgets/reading_row.dart';

final StateProvider<VitalType?> _historyTypeFilterProvider =
    StateProvider<VitalType?>((Ref ref) => null);

final StreamProviderFamily<List<VitalReading>, VitalType?> _historyProvider =
    StreamProvider.family<List<VitalReading>, VitalType?>((
      Ref ref,
      VitalType? type,
    ) {
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      return watchHistory(type: type);
    });

class VitalsHistoryScreen extends ConsumerWidget {
  const VitalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VitalType? filter = ref.watch(_historyTypeFilterProvider);
    final AsyncValue<List<VitalReading>> history = ref.watch(
      _historyProvider(filter),
    );

    return AppScaffold(
      title: 'vitals.historyTitle'.tr(),
      scrollable: false,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: Text('vitals.filterAll'.tr()),
                  selected: filter == null,
                  onSelected: (_) =>
                      ref.read(_historyTypeFilterProvider.notifier).state =
                          null,
                ),
                for (final VitalType type in VitalType.values)
                  ChoiceChip(
                    label: Text(vitalDescriptors[type]!.labelKey.tr()),
                    selected: filter == type,
                    onSelected: (_) =>
                        ref.read(_historyTypeFilterProvider.notifier).state =
                            type,
                  ),
              ],
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => EmptyState(
                title: 'errors.generic'.tr(),
                icon: Icons.error_outline_rounded,
              ),
              data: (List<VitalReading> readings) => readings.isEmpty
                  ? EmptyState(
                      icon: Icons.history,
                      title: 'vitals.historyEmptyTitle'.tr(),
                    )
                  : ListView.separated(
                      itemCount: readings.length,
                      separatorBuilder: (BuildContext context, int i) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) =>
                          ReadingRow(reading: readings[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
