// SQLite FTS5 offline index over every downloaded PDF.
//
// Schema
//   documents   one row per catalog item (hash, page count, OCR flag, embed state)
//   pages_fts   FTS5 table, one row per PDF page: body + title (indexed), ids (unindexed)
//               tokenizer porter+unicode61 (stemming, diacritics folded), prefix indexes for 2/3 chars
//   chunks      RAG chunks with optional embedding BLOB (Float32, 384-d); vec_chunks mirrors it
//
// Performance: WAL journal, one transaction per document, BM25 ranking with a title boost.
// Typical MATCH on ~50k pages answers in single-digit milliseconds on a 2022 mid-range phone.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../catalog/catalog_models.dart';
import '../core/storage_paths.dart';
import '../rag/chunker.dart';
import 'fts_query.dart';
import 'pdf_text_extractor.dart';

class SearchHit {
  SearchHit({required this.itemId, required this.title, required this.category, required this.page, required this.snippet, required this.score});
  final String itemId;
  final String title;
  final String category;
  final int page;
  /// Highlighted ranges are wrapped in \u0002 ... \u0003; the UI turns them into bold spans.
  final String snippet;
  final double score;
}

class SearchResult {
  SearchResult(this.hits, this.elapsed, {this.rewrittenQuery, this.error});
  final List<SearchHit> hits;
  final Duration elapsed;
  final String? rewrittenQuery;
  final String? error;
}

class IndexProgress {
  IndexProgress(this.itemId, this.page, this.pageCount);
  final String itemId;
  final int page;
  final int pageCount;
}

class FtsIndex {
  FtsIndex._(this.db);
  final Database db;

  static late FtsIndex instance;
  final _progress = StreamController<IndexProgress>.broadcast();
  Stream<IndexProgress> get progress => _progress.stream;
  Future<void> _queue = Future.value(); // serialises indexing jobs

  static FtsIndex open(String file, {String? sqlcipherKey}) {
    final db = sqlite3.open(file);
    if (sqlcipherKey != null) db.execute("PRAGMA key = '${sqlcipherKey.replaceAll("'", "''")}'");
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA temp_store = MEMORY');
    db.execute('''
      CREATE TABLE IF NOT EXISTS documents(
        id INTEGER PRIMARY KEY,
        item_id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        rel_path TEXT NOT NULL,
        sha256 TEXT,
        page_count INTEGER DEFAULT 0,
        text_pages INTEGER DEFAULT 0,
        status TEXT NOT NULL,            -- indexed | needsOcr | error
        error TEXT,
        indexed_at INTEGER,
        embedded INTEGER NOT NULL DEFAULT 0
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
        body, title,
        category UNINDEXED, doc_id UNINDEXED, page UNINDEXED,
        tokenize = 'porter unicode61 remove_diacritics 2',
        prefix = '2 3'
      );
      CREATE TABLE IF NOT EXISTS chunks(
        id INTEGER PRIMARY KEY,
        doc_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        page INTEGER NOT NULL,
        ord INTEGER NOT NULL,
        text TEXT NOT NULL,
        embedding BLOB
      );
      CREATE INDEX IF NOT EXISTS chunks_doc ON chunks(doc_id);
      CREATE INDEX IF NOT EXISTS chunks_unembedded ON chunks(id) WHERE embedding IS NULL;
    ''');
    return instance = FtsIndex._(db);
  }

  // ------------------------------------------------------------------ indexing

  /// Queue a verified PDF for indexing. Safe to call repeatedly: unchanged files (same hash) are skipped.
  Future<void> indexItem(CatalogItem item, {required String sha256}) {
    final next = _queue.then((_) => _index(item, sha256)).catchError((Object _) {});
    _queue = next;
    return next;
  }

  Future<void> _index(CatalogItem item, String sha256) async {
    final existing = db.select('SELECT id, sha256, status FROM documents WHERE item_id = ?', [item.id]);
    if (existing.isNotEmpty && existing.first['sha256'] == sha256 && existing.first['status'] != 'error') return;

    final path = StoragePaths.instance.resolve(item.target);
    if (!await File(path).exists()) return;

    // Extract first (async, PDFium off the UI thread), then write in one short transaction.
    final pages = <PageText>[];
    PdfExtractionResult? result;
    try {
      await for (final pt in PdfTextExtractor.pages(path, (n) => result = PdfExtractionResult(n))) {
        pages.add(pt);
        _progress.add(IndexProgress(item.id, pt.page, result!.pageCount));
      }
    } catch (e) {
      _upsertDocument(item, sha256, 0, 0, 'error', e.toString());
      return;
    }

    db.execute('BEGIN IMMEDIATE');
    try {
      final docId = _upsertDocument(item, sha256, result!.pageCount, result!.pagesWithText,
          result!.needsOcr ? 'needsOcr' : 'indexed', null);
      db.execute('DELETE FROM pages_fts WHERE doc_id = ?', [docId]);
      db.execute('DELETE FROM chunks WHERE doc_id = ?', [docId]);
      _deleteVectorsFor(docId);

      final insPage = db.prepare('INSERT INTO pages_fts(body, title, category, doc_id, page) VALUES (?, ?, ?, ?, ?)');
      final insChunk = db.prepare('INSERT INTO chunks(doc_id, page, ord, text) VALUES (?, ?, ?, ?)');
      try {
        for (final pg in pages) {
          if (pg.text.isEmpty) continue;
          insPage.execute([pg.text, item.title, item.categoryId, docId, pg.page]);
          for (final c in chunkPage(pg.page, pg.text)) {
            insChunk.execute([docId, c.page, c.ord, c.text]);
          }
        }
      } finally {
        insPage.close();
        insChunk.close();
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      _upsertDocument(item, sha256, 0, 0, 'error', e.toString());
    }
  }

  int _upsertDocument(CatalogItem item, String sha, int pageCount, int textPages, String status, String? error) {
    db.execute('''
      INSERT INTO documents(item_id, title, category, rel_path, sha256, page_count, text_pages, status, error, indexed_at, embedded)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
      ON CONFLICT(item_id) DO UPDATE SET
        title = excluded.title, category = excluded.category, rel_path = excluded.rel_path,
        sha256 = excluded.sha256, page_count = excluded.page_count, text_pages = excluded.text_pages,
        status = excluded.status, error = excluded.error, indexed_at = excluded.indexed_at, embedded = 0
    ''', [item.id, item.title, item.categoryId, item.target, sha, pageCount, textPages, status, error, DateTime.now().millisecondsSinceEpoch]);
    return db.select('SELECT id FROM documents WHERE item_id = ?', [item.id]).first['id'] as int;
  }

  /// Hook set by VectorStore when sqlite-vec is active, so stale vectors are removed with their chunks.
  void Function(int docId)? onDeleteVectors;
  void _deleteVectorsFor(int docId) => onDeleteVectors?.call(docId);

  Future<void> removeItem(String itemId) async {
    final rows = db.select('SELECT id FROM documents WHERE item_id = ?', [itemId]);
    if (rows.isEmpty) return;
    final docId = rows.first['id'] as int;
    db.execute('BEGIN');
    db.execute('DELETE FROM pages_fts WHERE doc_id = ?', [docId]);
    _deleteVectorsFor(docId);
    db.execute('DELETE FROM documents WHERE id = ?', [docId]); // cascades to chunks
    db.execute('COMMIT');
  }

  // ------------------------------------------------------------------ search

  SearchResult search(String userQuery, {String? category, int limit = 30, int offset = 0}) {
    final sw = Stopwatch()..start();
    final match = FtsQuery.build(userQuery);
    if (match == null) return SearchResult(const [], sw.elapsed, error: 'Nothing to search for');

    List<SearchHit> run(String expr) {
      final sql = StringBuffer('''
        SELECT d.item_id, d.title, d.category, f.page,
               snippet(pages_fts, 0, char(2), char(3), ' … ', 14) AS snip,
               bm25(pages_fts, 1.0, 6.0) AS score
        FROM pages_fts f JOIN documents d ON d.id = f.doc_id
        WHERE pages_fts MATCH ?''');
      final args = <Object?>[expr];
      if (category != null) {
        sql.write(' AND f.category = ?');
        args.add(category);
      }
      sql.write(' ORDER BY score LIMIT ? OFFSET ?');
      args
        ..add(limit)
        ..add(offset);
      return [
        for (final r in db.select(sql.toString(), args))
          SearchHit(
            itemId: r['item_id'] as String,
            title: r['title'] as String,
            category: r['category'] as String,
            page: r['page'] as int,
            snippet: r['snip'] as String,
            score: (r['score'] as num).toDouble(),
          ),
      ];
    }

    try {
      return SearchResult(run(match), sw.elapsed, rewrittenQuery: match);
    } on SqliteException {
      final phrase = FtsQuery.asPhrase(userQuery);
      try {
        return SearchResult(run(phrase), sw.elapsed, rewrittenQuery: phrase);
      } on SqliteException catch (e) {
        return SearchResult(const [], sw.elapsed, error: e.message);
      }
    }
  }

  /// Library-wide counts for the status screen.
  Map<String, int> stats() {
    final r = db.select('''
      SELECT (SELECT count(*) FROM documents) AS docs,
             (SELECT coalesce(sum(page_count), 0) FROM documents) AS pages,
             (SELECT count(*) FROM documents WHERE status = 'needsOcr') AS needs_ocr,
             (SELECT count(*) FROM chunks) AS chunks,
             (SELECT count(*) FROM chunks WHERE embedding IS NULL) AS unembedded
    ''').first;
    return {for (final k in r.keys) k: r[k] as int};
  }

  /// Keeps the FTS index compact after large imports (run when idle and on charger).
  void optimize() => db.execute("INSERT INTO pages_fts(pages_fts) VALUES ('optimize')");

  String dbPath() => p.normalize(StoragePaths.instance.dbFile);
}
