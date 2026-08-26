import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_log.dart';
import '../../medication_providers.dart';

class DoseHistoryFilter {
  const DoseHistoryFilter({this.medicationClientRecordId, this.from, this.to});
  final String? medicationClientRecordId;
  final DateTime? from;
  final DateTime? to;
}

class DoseHistoryController extends AsyncNotifier<List<DoseLog>> {
  DoseHistoryFilter _filter = const DoseHistoryFilter();

  @override
  Future<List<DoseLog>> build() => _fetch();

  Future<List<DoseLog>> _fetch() {
    return ref.watch(medicationRepositoryProvider).doseHistory(
      medicationClientRecordId: _filter.medicationClientRecordId,
      from: _filter.from,
      to: _filter.to,
    );
  }

  Future<void> setFilter(DoseHistoryFilter filter) async {
    _filter = filter;
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<DoseHistoryController, List<DoseLog>>
doseHistoryControllerProvider =
    AsyncNotifierProvider<DoseHistoryController, List<DoseLog>>(
      DoseHistoryController.new,
    );
