// "Add my own PDFs": the user picks PDFs from the phone (Files, Downloads, SD card) and the app copies them into
// the My_Documents folder of the library, then indexes them like any other document. Nothing leaves the device.
// The app ships none of these files, so the user is responsible for having the right to keep them.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../core/services.dart';
import '../core/storage_paths.dart';
import 'local_library.dart';

class MyDocuments {
  static const dirName = 'My_Documents';

  static Directory get dir => Directory(p.join(StoragePaths.instance.libraryRoot, dirName));

  /// Lets the user choose PDFs and copies them in. Returns how many were added, or null if the picker was cancelled.
  static Future<MyDocsResult?> pickAndAdd() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose PDFs to add',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked.isEmpty) return null;
    await dir.create(recursive: true);
    var added = 0, skipped = 0;
    for (final f in picked) {
      final src = f.path;
      if (src == null || !f.name.toLowerCase().endsWith('.pdf')) {
        skipped++;
        continue;
      }
      var name = f.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      var dest = File(p.join(dir.path, name));
      var n = 2;
      while (await dest.exists()) {
        // Same name already there: keep both unless it is plainly the same file.
        if (await dest.length() == await File(src).length()) {
          dest = File('');
          break;
        }
        dest = File(p.join(dir.path, '${p.basenameWithoutExtension(name)} ($n).pdf'));
        n++;
      }
      if (dest.path.isEmpty) {
        skipped++;
        continue;
      }
      await File(src).copy(dest.path);
      added++;
    }
    if (added > 0) await LocalLibrary.scanAndIndex(Services.catalog, StoragePaths.instance);
    return MyDocsResult(added, skipped);
  }

  /// The user's own files, newest first.
  static Future<List<File>> list() async {
    if (!await dir.exists()) return [];
    final files = [
      await for (final e in dir.list(followLinks: false))
        if (e is File && e.path.toLowerCase().endsWith('.pdf')) e,
    ];
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  static Future<void> remove(File f) async {
    await f.delete();
    await LocalLibrary.scanAndIndex(Services.catalog, StoragePaths.instance);
  }
}

class MyDocsResult {
  const MyDocsResult(this.added, this.skipped);
  final int added;
  final int skipped;
}
