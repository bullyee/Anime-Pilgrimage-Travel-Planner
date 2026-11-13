import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How a frame is prepared before it goes to Google Drive, chosen by the
/// user (Settings, or the upload dialog). A frame whose longest edge is at
/// most [maxEdge] always goes up as the original file; only larger ones are
/// scaled down to [maxEdge] and saved as a JPEG at [jpegQuality].
///
/// The data savings are measured on real 1920 × 1080 anime frames
/// (283 KB as they are, 195 KB at 1280 px quality 90, 141 KB at 1280 px
/// quality 82). Re-encoding at full size saves nothing (it came out larger
/// than the original), so there is no "full size, compressed" option.
enum DriveUploadQuality {
  original(
    maxEdge: 1920,
    jpegQuality: 90,
    label: 'Original',
    detail: 'Best quality. Frames up to 1920 px go up as they are; larger ones are scaled to 1920 px.',
  ),
  smaller(
    maxEdge: 1280,
    jpegQuality: 90,
    label: 'Smaller',
    detail: '1280 px at high JPEG quality. About 30% less data for a full HD frame.',
  ),
  smallest(
    maxEdge: 1280,
    jpegQuality: 82,
    label: 'Smallest',
    detail: '1280 px JPEG. About half the data for a full HD frame; flat colours can pick up some JPEG noise.',
  );

  const DriveUploadQuality({
    required this.maxEdge,
    required this.jpegQuality,
    required this.label,
    required this.detail,
  });

  /// The longest edge an uploaded frame keeps.
  final int maxEdge;

  /// JPEG quality for the frames that have to be scaled down.
  final int jpegQuality;

  final String label;
  final String detail;

  /// The saved name back to a value; anything unknown is [original].
  static DriveUploadQuality fromName(String? name) =>
      values.firstWhere((q) => q.name == name?.trim(), orElse: () => original);
}

/// Where the choice is kept. One per phone, not per account.
abstract class DriveUploadQualityStore {
  Future<DriveUploadQuality> read();
  Future<void> write(DriveUploadQuality quality);
}

/// Keeps the choice in a small file in the app's support folder.
class FileDriveUploadQualityStore implements DriveUploadQualityStore {
  FileDriveUploadQualityStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(p.join((await _directory()).path, 'drive_upload_quality.txt'));

  @override
  Future<DriveUploadQuality> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return DriveUploadQuality.original;
      return DriveUploadQuality.fromName(await f.readAsString());
    } catch (_) {
      return DriveUploadQuality.original;
    }
  }

  @override
  Future<void> write(DriveUploadQuality quality) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(quality.name, flush: true);
  }
}

/// For tests and anywhere without a file system.
class InMemoryDriveUploadQualityStore implements DriveUploadQualityStore {
  InMemoryDriveUploadQualityStore([this.value = DriveUploadQuality.original]);

  DriveUploadQuality value;

  @override
  Future<DriveUploadQuality> read() async => value;

  @override
  Future<void> write(DriveUploadQuality quality) async => value = quality;
}
