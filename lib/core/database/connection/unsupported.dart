import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum WebStorageStatus {
  persistent,
  unsafeIndexedDb,
  inMemory,
}

final ValueNotifier<WebStorageStatus?> webStorageStatusNotifier = ValueNotifier(null);

/// Fallback executor if the platform is completely unrecognized.
QueryExecutor openConnection() {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform.',
  );
}
