import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/drive_upload_quality.dart';

final driveUploadQualityStoreProvider = Provider<DriveUploadQualityStore>(
  (ref) => kIsWeb ? InMemoryDriveUploadQualityStore() : FileDriveUploadQualityStore(),
);

/// The upload quality the user chose for frames sent to Google Drive
/// ([DriveUploadQuality.original] until they choose).
final driveUploadQualityProvider = NotifierProvider<DriveUploadQualityNotifier, DriveUploadQuality>(
  DriveUploadQualityNotifier.new,
);

class DriveUploadQualityNotifier extends Notifier<DriveUploadQuality> {
  late Future<void> _loaded;
  bool _chosenHere = false;

  @override
  DriveUploadQuality build() {
    final store = ref.watch(driveUploadQualityStoreProvider);
    _chosenHere = false;
    _loaded = store.read().then((saved) {
      if (!_chosenHere) state = saved;
    }, onError: (Object _) {});
    return DriveUploadQuality.original;
  }

  /// The saved choice, once it has been read (an upload resumed right after
  /// the app starts must not fall back to the default).
  Future<DriveUploadQuality> current() async {
    await _loaded;
    return state;
  }

  /// Uses [quality] from now on and remembers it.
  Future<void> choose(DriveUploadQuality quality) async {
    _chosenHere = true;
    state = quality;
    try {
      await ref.read(driveUploadQualityStoreProvider).write(quality);
    } catch (e) {
      debugPrint('[DriveUploadQuality] could not save the choice: $e');
    }
  }
}
