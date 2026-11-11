import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Opens a WebAssembly SQLite3 database connection.
///
/// Drift automatically picks the best persistent backend available in the
/// browser (`opfsShared`, `opfsLocks`, `sharedIndexedDb`, or `unsafeIndexedDb`).
/// We only log when falling back to `inMemory` rather than rejecting browsers
/// like Chrome or iOS Safari that lack `dedicatedWorkersInSharedWorkers` or
/// strict COOP/COEP isolation headers (which also conflict with Google OAuth popups).
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      // Aligned with the native filename base ('trip_planner') so the logical
      // database name is consistent across platforms.
      databaseName: 'trip_planner',
      sqlite3Uri: Uri.parse('/sqlite3.wasm'),
      driftWorkerUri: Uri.parse('/drift_worker.js'),
    );

    if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
      debugPrint(
        'Drift Wasm database using in-memory storage '
        '(missing features: ${result.missingFeatures}).',
      );
    }

    return result.resolvedExecutor;
  }));
}
