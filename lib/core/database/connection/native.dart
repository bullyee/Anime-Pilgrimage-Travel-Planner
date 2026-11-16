import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum WebStorageStatus {
  persistent,
  unsafeIndexedDb,
  inMemory,
}

final ValueNotifier<WebStorageStatus?> webStorageStatusNotifier = ValueNotifier(null);

/// Opens a native SQLite database connection for mobile and desktop platforms.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'trip_planner.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
