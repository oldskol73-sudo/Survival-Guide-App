// Writes extracted tiles into an MBTiles file (SQLite), the format the app's tile server reads.
// Tiles stay gzip-compressed exactly as stored in the source, and rows are flipped to TMS order.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'pmtiles.dart';

class MbtilesSink implements TileSink {
  MbtilesSink(this.path);
  final String path;

  Database? _db;
  int _sinceCommit = 0;

  @override
  Future<void> begin(PmtilesHeader h, Map<String, dynamic> metadata, TileSelection s) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
    final db = _db = sqlite3.open(path);
    db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    db.execute('CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)');
    db.execute('CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)');
    final meta = <String, String>{
      'name': (metadata['name'] as String?) ?? 'Offline map',
      'format': 'pbf',
      'type': 'baselayer',
      'version': '${metadata['version'] ?? 1}',
      'description': (metadata['description'] as String?) ?? '',
      'attribution': 'OpenStreetMap contributors (ODbL); Natural Earth',
      'bounds': '${s.west},${s.south},${s.east},${s.north}',
      'center': '${(s.west + s.east) / 2},${(s.south + s.north) / 2},${s.maxZoom < 10 ? s.maxZoom : 10}',
      'minzoom': '${s.minZoom}',
      'maxzoom': '${s.maxZoom}',
      'json': jsonEncode({'vector_layers': metadata['vector_layers'] ?? const []}),
    };
    for (final e in meta.entries) {
      db.execute('INSERT INTO metadata VALUES (?, ?)', [e.key, e.value]);
    }
    db.execute('BEGIN');
  }

  @override
  Future<void> add(int z, int x, int y, Uint8List data) async {
    _db!.execute('INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)', [z, x, (1 << z) - 1 - y, data]);
    if (++_sinceCommit >= 2000) {
      _db!.execute('COMMIT');
      _db!.execute('BEGIN');
      _sinceCommit = 0;
    }
  }

  @override
  Future<void> finish() async {
    final db = _db;
    if (db == null) return;
    db.execute('COMMIT');
    db.close();
    _db = null;
  }

  /// Closes and deletes a half-written file (cancelled or failed download).
  Future<void> abort() async {
    try {
      _db?.close();
    } catch (_) {}
    _db = null;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
