import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_locale.dart';
import 'locale_store.dart';

/// Keeps the user's UI language choice in a small file inside application support storage.
class FileAppLocaleStore implements AppLocaleStore {
  FileAppLocaleStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(p.join((await _directory()).path, 'app_locale.txt'));

  @override
  Future<AppLocaleOption> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return AppLocaleOption.system;
      return AppLocaleOption.fromTag(await f.readAsString());
    } catch (_) {
      return AppLocaleOption.system;
    }
  }

  @override
  Future<void> write(AppLocaleOption option) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(option.tag, flush: true);
  }
}

AppLocaleStore createPlatformAppLocaleStore() => FileAppLocaleStore();
