import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../datasources/vitals_local_datasource.dart';
import '../models/vital_model.dart';

/// Note what this does **not** do: it does not check connectivity and it
/// does not call the API. Writes go local-then-queue, unconditionally
/// (`CONTRIBUTING.md` §8). It holds no `Dio` and no
/// `VitalsRemoteDataSource` — there is no path through which a write here
/// could reach the network.
class VitalsRepositoryImpl implements VitalsRepository {
  // The public `local`/`sync` parameter names are the DI-wiring API this
  // class is constructed with (Task 10); the private fields below are the
  // internal names used throughout this file. An initializing formal can't
  // bridge a public parameter name to a differently-named private field, so
  // these two are exempt from `prefer_initializing_formals`.
  const VitalsRepositoryImpl({
    required VitalsLocalDataSource local,
    required SyncEnqueuer sync,
  }) : _local = local, // ignore: prefer_initializing_formals
       _sync = sync; // ignore: prefer_initializing_formals

  final VitalsLocalDataSource _local;
  final SyncEnqueuer _sync;

  @override
  Future<void> log(VitalReading reading) async {
    final VitalModel model = VitalModel.fromEntity(reading);
    await _local.insert(model); // 1. device first, always
    await _sync.enqueue(
      // 2. then owe it to the server
      clientRecordId: reading.clientRecordId,
      entityType: SyncEntityType.vital,
      payload: model.toJson(),
      recordedAt: reading.measuredAt,
    );
  } // never awaits the network

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    return _local
        .watchHistory(type: type, from: from, to: to)
        .map(
          (List<VitalModel> models) =>
              models.map((VitalModel m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    final VitalModel? model = await _local.latestByType(type);
    return model?.toEntity();
  }

  @override
  Future<double?> patientHeightCm() => _local.readHeightCm();

  @override
  Future<VitalGoals?> patientGoals() => _local.readGoals();
}
