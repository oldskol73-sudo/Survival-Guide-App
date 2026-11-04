// Vector retrieval over chunk embeddings.
//
// Source of truth: chunks.embedding (Float32 BLOB, L2-normalised, 384-d) in library.db.
// Accelerator:     sqlite-vec `vec0` table (cosine) when the extension loads.
// Fallback:        streaming brute-force dot product with a bounded top-k, so the feature keeps working
//                  if the native extension is missing, at roughly 2 ms per 1,000 chunks.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../search/fts_index.dart';
import 'embedder.dart';

class ChunkHit {
  ChunkHit({required this.chunkId, required this.score, required this.text, required this.page, required this.itemId, required this.title, required this.category});
  final int chunkId;
  final double score; // cosine similarity, higher is better
  final String text;
  final int page;
  final String itemId;
  final String title;
  final String category;
}

class VectorStore {
  VectorStore._(this._fts, this.usingSqliteVec);
  final FtsIndex _fts;
  final bool usingSqliteVec;
  Database get _db => _fts.db;

  static late VectorStore instance;

  /// Must run BEFORE FtsIndex.open(): sqlite3 registers the extension for databases opened afterwards.
  static bool registerSqliteVec() {
    try {
      final lib = Platform.isAndroid ? DynamicLibrary.open('libsqlite_vec.so') : DynamicLibrary.process();
      sqlite3.ensureExtensionLoaded(SqliteExtension.inLibrary(lib, 'sqlite3_vec_init'));
      return true;
    } catch (_) {
      return false;
    }
  }

  static VectorStore attach(FtsIndex fts, {required bool extensionRegistered}) {
    var vec = false;
    if (extensionRegistered) {
      try {
        fts.db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(embedding float[$embeddingDim] distance_metric=cosine)');
        vec = true;
      } on SqliteException {
        vec = false;
      }
    }
    final store = VectorStore._(fts, vec);
    if (vec) {
      fts.onDeleteVectors = (docId) =>
          fts.db.execute('DELETE FROM vec_chunks WHERE rowid IN (SELECT id FROM chunks WHERE doc_id = ?)', [docId]);
      store._backfillVecTable();
    }
    return instance = store;
  }

  static Uint8List _blob(Float32List v) => v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);

  void write(int chunkId, Float32List v) {
    _db.execute('UPDATE chunks SET embedding = ? WHERE id = ?', [_blob(v), chunkId]);
    if (usingSqliteVec) {
      // vec0 virtual tables do not honour OR REPLACE; delete then insert.
      _db.execute('DELETE FROM vec_chunks WHERE rowid = ?', [chunkId]);
      _db.execute('INSERT INTO vec_chunks(rowid, embedding) VALUES (?, ?)', [chunkId, _blob(v)]);
    }
  }

  /// If the extension appears after embeddings already exist (e.g. app update), copy them across once.
  void _backfillVecTable() {
    _db.execute('''
      INSERT INTO vec_chunks(rowid, embedding)
      SELECT c.id, c.embedding FROM chunks c
      WHERE c.embedding IS NOT NULL AND c.id NOT IN (SELECT rowid FROM vec_chunks)
    ''');
  }

  List<ChunkHit> topK(Float32List query, {int k = 8, String? category}) {
    final ids = usingSqliteVec ? _topKVec(query, k, category) : _topKBrute(query, k, category);
    if (ids.isEmpty) return const [];
    final byId = {for (final e in ids) e.$1: e.$2};
    final rows = _db.select('''
      SELECT c.id, c.text, c.page, d.item_id, d.title, d.category
      FROM chunks c JOIN documents d ON d.id = c.doc_id
      WHERE c.id IN (${List.filled(ids.length, '?').join(',')})
    ''', [for (final e in ids) e.$1]);
    final hits = [
      for (final r in rows)
        ChunkHit(
          chunkId: r['id'] as int,
          score: byId[r['id'] as int]!,
          text: r['text'] as String,
          page: r['page'] as int,
          itemId: r['item_id'] as String,
          title: r['title'] as String,
          category: r['category'] as String,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return hits;
  }

  List<(int, double)> _topKVec(Float32List q, int k, String? category) {
    // vec0 KNN has no join filter here, so over-fetch when a category is requested and filter after.
    final fetch = category == null ? k : k * 6;
    final rows = _db.select('''
      SELECT v.rowid AS id, v.distance AS dist
      FROM vec_chunks v
      WHERE v.embedding MATCH ? AND k = ?
      ORDER BY v.distance
    ''', [_blob(q), fetch]);
    var out = [for (final r in rows) (r['id'] as int, 1.0 - (r['dist'] as num).toDouble())];
    if (category != null && out.isNotEmpty) {
      final allowed = {
        for (final r in _db.select(
            'SELECT c.id FROM chunks c JOIN documents d ON d.id = c.doc_id WHERE d.category = ? AND c.id IN (${List.filled(out.length, '?').join(',')})',
            [category, for (final e in out) e.$1]))
          r['id'] as int,
      };
      out = out.where((e) => allowed.contains(e.$1)).toList();
    }
    return out.take(k).toList();
  }

  List<(int, double)> _topKBrute(Float32List q, int k, String? category) {
    final stmt = _db.prepare(category == null
        ? 'SELECT id, embedding FROM chunks WHERE embedding IS NOT NULL'
        : 'SELECT c.id, c.embedding FROM chunks c JOIN documents d ON d.id = c.doc_id WHERE c.embedding IS NOT NULL AND d.category = ?');
    final best = <(int, double)>[]; // kept sorted descending, length <= k
    try {
      final cursor = stmt.selectCursor(category == null ? const [] : [category]);
      while (cursor.moveNext()) {
        final row = cursor.current;
        final bytes = row['embedding'] as Uint8List;
        if (bytes.lengthInBytes != embeddingDim * 4) continue;
        // BLOB bytes may not be 4-byte aligned; copy into an aligned buffer before viewing as floats.
        final v = Float32List.view(Uint8List.fromList(bytes).buffer);
        var dot = 0.0;
        for (var i = 0; i < embeddingDim; i++) {
          dot += v[i] * q[i];
        }
        if (best.length < k || dot > best.last.$2) {
          final entry = (row['id'] as int, dot);
          var pos = best.indexWhere((e) => e.$2 < dot);
          if (pos < 0) pos = best.length;
          best.insert(pos, entry);
          if (best.length > k) best.removeLast();
        }
      }
    } finally {
      stmt.close();
    }
    return best;
  }
}

/// Embeds chunks that have no vector yet, in small batches, yielding between batches.
/// Paused automatically in low-power mode or when background embedding is switched off.
class EmbeddingScheduler {
  EmbeddingScheduler(this._fts, this._store, this._embedder, {required this.isAllowed});
  final FtsIndex _fts;
  final VectorStore _store;
  final Embedder _embedder;
  final bool Function() isAllowed;
  bool _running = false;

  Future<void> run({int batch = 16}) async {
    if (_running) return;
    _running = true;
    try {
      while (isAllowed()) {
        final rows = _fts.db.select('SELECT id, text FROM chunks WHERE embedding IS NULL LIMIT ?', [batch]);
        if (rows.isEmpty) break;
        final vecs = await _embedder.embedBatch([for (final r in rows) r['text'] as String]);
        _fts.db.execute('BEGIN');
        for (var i = 0; i < rows.length; i++) {
          _store.write(rows[i]['id'] as int, vecs[i]);
        }
        _fts.db.execute('COMMIT');
        await Future<void>.delayed(const Duration(milliseconds: 20)); // let the UI and OS breathe
      }
      _fts.db.execute('''
        UPDATE documents SET embedded = 1
        WHERE embedded = 0 AND NOT EXISTS (SELECT 1 FROM chunks c WHERE c.doc_id = documents.id AND c.embedding IS NULL)
      ''');
    } finally {
      _running = false;
    }
  }
}
