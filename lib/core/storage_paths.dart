// Resolves every on-disk location. Private state stays in the app sandbox; the library goes to a
// user-visible location (iOS Documents, Android app-specific external dir on internal or microSD).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageVolume {
  StorageVolume(this.label, this.root, {required this.removable});
  final String label;
  final String root; // absolute; library lives at <root>/SurvivalNode/library
  final bool removable;
}

class StoragePaths {
  StoragePaths._(this.appSupport, this.libraryRoot, this.volume);

  final String appSupport; // private sandbox
  final String libraryRoot; // user-visible library
  final StorageVolume volume;

  String get dbDir => p.join(appSupport, 'db');
  String get dbFile => p.join(dbDir, 'library.db');
  String get modelsDir => p.join(appSupport, 'models');
  String get stateDir => p.join(appSupport, 'state');
  String get tmpDir => p.join(appSupport, 'tmp');
  String get quarantineDir => p.join(tmpDir, 'quarantine');

  static late StoragePaths instance;

  /// Volumes the user can pick in Settings. Android lists every mounted volume (internal first,
  /// then microSD/USB-OTG). No storage permission is needed for these app-specific directories.
  static Future<List<StorageVolume>> availableVolumes() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories() ?? const <Directory>[];
      return [
        for (var i = 0; i < dirs.length; i++)
          StorageVolume(i == 0 ? 'Internal storage' : 'SD card / external ${i}', dirs[i].path, removable: i > 0),
      ];
    }
    final docs = await getApplicationDocumentsDirectory();
    return [StorageVolume('On this iPhone/iPad (Files app)', docs.path, removable: false)];
  }

  static Future<StoragePaths> init({int volumeIndex = 0}) async {
    final support = (await getApplicationSupportDirectory()).path;
    final volumes = await availableVolumes();
    // Fall back to internal if the chosen SD card is missing (ejected, swapped phone).
    final vol = (volumeIndex < volumes.length) ? volumes[volumeIndex] : volumes.first;
    final library = p.join(vol.root, 'SurvivalNode', 'library');

    final sp = StoragePaths._(support, library, vol);
    for (final d in [sp.dbDir, sp.modelsDir, sp.stateDir, sp.tmpDir, sp.quarantineDir, sp.libraryRoot]) {
      await Directory(d).create(recursive: true);
    }
    // Clear stale partial files from a previous crash (the downloader keeps its own temp files).
    await for (final f in Directory(sp.tmpDir).list()) {
      if (f is File && f.path.endsWith('.part')) {
        await f.delete().catchError((_) => f);
      }
    }
    instance = sp;
    return sp;
  }

  /// Maps a catalog `target` onto an absolute path, re-checking that it stays inside its root.
  String resolve(String target) {
    final isModel = target.startsWith('@models/');
    final base = isModel ? modelsDir : libraryRoot;
    final rel = isModel ? target.substring('@models/'.length) : target;
    final full = p.normalize(p.join(base, rel));
    if (!p.isWithin(base, full)) {
      throw StateError('target escapes sandbox: $target');
    }
    return full;
  }
}
