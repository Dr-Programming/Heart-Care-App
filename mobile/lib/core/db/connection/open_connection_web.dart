import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web database: drift's WebAssembly-backed `WasmDatabase`. Requires
/// `web/sqlite3.wasm` and `web/drift_worker.dart.js` to be served alongside the
/// app bundle (see `mobile/web/`).
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final WasmDatabaseResult result = await WasmDatabase.open(
      databaseName: 'libu_care',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}
