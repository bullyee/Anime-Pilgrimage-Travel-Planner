import 'dart:js_interop';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

enum WebStorageStatus {
  persistent,
  unsafeIndexedDb,
  inMemory,
}

final ValueNotifier<WebStorageStatus?> webStorageStatusNotifier = ValueNotifier(null);

/// Opens a WebAssembly SQLite3 database connection.
///
/// Drift automatically picks the best persistent backend available in the
/// browser (`opfsShared`, `opfsLocks`, `sharedIndexedDb`, or `unsafeIndexedDb`).
/// We only log when falling back to `inMemory` rather than rejecting browsers
/// like Chrome or iOS Safari that lack `dedicatedWorkersInSharedWorkers` or
/// strict COOP/COEP isolation headers (which also conflict with Google OAuth popups).
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    // Resolving against document.baseURI honours <base href="$FLUTTER_BASE_HREF">
    // and works seamlessly on deep link paths like /join/:invite or /trips/:id.
    final baseUri = Uri.parse(web.document.baseURI);
    final result = await WasmDatabase.open(
      // Aligned with the native filename base ('trip_planner') so the logical
      // database name is consistent across platforms.
      databaseName: 'trip_planner',
      sqlite3Uri: baseUri.resolve('sqlite3.wasm'),
      driftWorkerUri: baseUri.resolve('drift_worker.js'),
    );

    if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
      debugPrint(
        'Drift Wasm database using in-memory storage '
        '(missing features: ${result.missingFeatures}).',
      );
      webStorageStatusNotifier.value = WebStorageStatus.inMemory;
      try {
        web.window.onbeforeunload = ((web.BeforeUnloadEvent event) {
          event.returnValue = 'Places and trips will not be saved across reloads.';
        }).toJS;
      } catch (_) {}
    } else if (result.chosenImplementation == WasmStorageImplementation.unsafeIndexedDb) {
      debugPrint('Drift Wasm database using unsafeIndexedDb without cross-tab lock.');
      webStorageStatusNotifier.value = WebStorageStatus.unsafeIndexedDb;
    } else {
      webStorageStatusNotifier.value = WebStorageStatus.persistent;
    }

    return result.resolvedExecutor;
  }));
}
