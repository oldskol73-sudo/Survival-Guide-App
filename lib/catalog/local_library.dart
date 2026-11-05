// Finds PDFs that are in the library folder but did not arrive through the download catalog (copied over by cable,
// SD card or the Files app) and makes them searchable. Each file becomes a runtime-only catalog item; the files
// themselves are never modified or moved.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/services.dart';
import '../core/storage_paths.dart';
import 'catalog_models.dart';

class LocalLibrary {
  /// Folders that are not a catalog category on their own, mapped to the category their PDFs belong to.
  static const _extraDirs = {'Wildflower_Doomsday_Disks': 'longterm'};

  /// Folders that hold copies, backups or unsorted material and must not be indexed.
  static bool _skip(String top) => top.startsWith('_') || top == '11_Maps' || top == '10_Kiwix_ZIM';

  static Future<void> scanAndIndex(Catalog catalog, StoragePaths paths) async {
    final known = {for (final i in catalog.allItems) i.target};
    final byDir = {for (final c in catalog.categories) c.dir: c.id, ..._extraDirs};
    final root = Directory(paths.libraryRoot);
    if (!await root.exists()) return;

    final found = <CatalogItem>[];
    final stamps = <String, String>{};
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.pdf')) continue;
      final rel = p.posix.joinAll(p.split(p.relative(e.path, from: paths.libraryRoot)));
      final top = rel.split('/').first;
      final cat = byDir[top];
      if (cat == null || _skip(top) || known.contains(rel)) continue;
      final id = 'local-${_fnv(rel)}';
      final st = await e.stat();
      stamps[id] = '${st.size}:${st.modified.millisecondsSinceEpoch}';
      found.add(CatalogItem(
        id: id,
        title: p.basenameWithoutExtension(rel).replaceAll('_', ' '),
        url: Uri.parse('local://$rel'),
        mirrors: const [],
        sha256: null,
        sha256Url: null,
        sizeBytes: st.size,
        target: rel,
        license: 'Local file',
        index: true,
        categoryId: cat,
        kind: CategoryKind.pdf,
      ));
    }
    catalog.localItems
      ..clear()
      ..addAll(found);
    // Size+modified time stands in for a hash: unchanged files are skipped without reading them again.
    for (final item in found) {
      await Services.fts.indexItem(item, sha256: stamps[item.id]!);
    }
    // Forget documents that were deleted from the folder, so search never offers a file that is not there.
    final live = {for (final i in found) i.id};
    final stale = [
      for (final r in Services.fts.db.select("SELECT item_id FROM documents WHERE item_id LIKE 'local-%'"))
        if (!live.contains(r['item_id'] as String)) r['item_id'] as String,
    ];
    for (final id in stale) {
      await Services.fts.removeItem(id);
    }
  }

  /// Two 32-bit FNV-1a hashes with different seeds, hex. Stable across launches, so a file keeps its id (and its
  /// index) between scans, and collisions across a few thousand paths are practically impossible.
  static String _fnv(String s) {
    String one(int seed) {
      var h = seed;
      for (final b in s.codeUnits) {
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
      }
      return h.toRadixString(16).padLeft(8, '0');
    }

    return one(0x811c9dc5) + one(0x9747b28c);
  }
}
