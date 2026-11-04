// In-process HTTP server bound to 127.0.0.1 only. Feeds the WebView (ZIM articles) and MapLibre
// (vector tiles, style, glyphs) from local files, so neither ever needs a remote server.
//
// Any app on the phone can connect to a loopback port, so every URL carries a random per-launch
// token; requests without it get 404. Responses carry a CSP that forbids remote subresources.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../catalog/catalog_models.dart';
import '../core/storage_paths.dart';
import 'zim_ffi.dart';

class LoopbackServer {
  LoopbackServer._(this._server, this.token);
  final HttpServer _server;
  final String token;

  static LoopbackServer? _instance;
  static LoopbackServer? get instance => _instance;

  int get port => _server.port;
  String get base => 'http://127.0.0.1:$port/$token';
  String zimUrl(String itemId, [String path = '']) => '$base/zim/$itemId/$path';
  String styleUrl(String mapId) => '$base/maps/$mapId/style.json';

  static final _zimHandles = <String, int>{};
  static final _mbtiles = <String, Database>{};

  static Future<LoopbackServer> start(Catalog catalog) async {
    if (_instance != null) return _instance!;
    final rnd = Random.secure();
    final token = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final styleTemplate = await rootBundle.loadString('assets/maps/style.json');

    CatalogItem? item(String id, CategoryKind kind) {
      final i = catalog.itemById(id);
      return (i != null && i.kind == kind) ? i : null;
    }

    final r = Router()
      // ---- ZIM
      ..get('/$token/zim/<book>/', (Request req, String book) {
        final h = _zim(item(book, CategoryKind.zim));
        final main = h == null ? null : ZimLib.instance!.mainPath(h);
        return main == null ? Response.notFound('no main page') : Response.found('/$token/zim/$book/$main');
      })
      ..get('/$token/zim/<book>/-/suggest', (Request req, String book) {
        final h = _zim(item(book, CategoryKind.zim));
        if (h == null) return Response.notFound('');
        final q = req.url.queryParameters['q'] ?? '';
        final res = ZimLib.instance!.suggest(h, q);
        return Response.ok(jsonEncode([for (final (path, title) in res) {'path': path, 'title': title}]),
            headers: {'content-type': 'application/json'});
      })
      ..get('/$token/zim/<book>/<path|.*>', (Request req, String book, String path) {
        final h = _zim(item(book, CategoryKind.zim));
        if (h == null) return Response.notFound('archive unavailable');
        final e = ZimLib.instance!.get(h, Uri.decodeComponent(path));
        if (e == null) return Response.notFound('not in archive');
        return Response.ok(e.bytes, headers: {'content-type': e.mimeType, 'cache-control': 'max-age=86400'});
      })
      // ---- Maps
      ..get('/$token/maps/<map>/style.json', (Request req, String map) {
        final style = styleTemplate
            .replaceAll('__TILES__', 'http://127.0.0.1:${_instance!.port}/$token/tiles/$map/{z}/{x}/{y}.pbf')
            .replaceAll('__GLYPHS__', 'http://127.0.0.1:${_instance!.port}/$token/fonts/{fontstack}/{range}.pbf');
        return Response.ok(style, headers: {'content-type': 'application/json'});
      })
      ..get('/$token/tiles/<map>/<z|[0-9]+>/<x|[0-9]+>/<y|[0-9]+>.pbf', (Request req, String map, String z, String x, String y) {
        final db = _mb(item(map, CategoryKind.map));
        if (db == null) return Response.notFound('');
        final zi = int.parse(z), xi = int.parse(x), yi = int.parse(y);
        if (zi > 22) return Response.notFound('');
        final tmsY = (1 << zi) - 1 - yi; // MBTiles stores rows bottom-up (TMS)
        final rows = db.select('SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?', [zi, xi, tmsY]);
        if (rows.isEmpty) return Response(204); // empty ocean/out of extract: not an error
        final data = rows.first['tile_data'] as List<int>;
        final gz = data.length > 2 && data[0] == 0x1f && data[1] == 0x8b;
        return Response.ok(data, headers: {
          'content-type': 'application/x-protobuf',
          if (gz) 'content-encoding': 'gzip',
        });
      })
      ..get('/$token/fonts/<stack>/<range>.pbf', (Request req, String stack, String range) async {
        // Glyph packs live in library/11_Maps/fonts/<Font Stack>/<0-255>.pbf
        final first = Uri.decodeComponent(stack).split(',').first.trim();
        final dir = p.join(StoragePaths.instance.libraryRoot, '11_Maps', 'fonts');
        final f = File(p.normalize(p.join(dir, first, '$range.pbf')));
        if (!p.isWithin(dir, f.path) || !await f.exists()) return Response.notFound('');
        return Response.ok(await f.readAsBytes(), headers: {'content-type': 'application/x-protobuf'});
      });

    Middleware security() => (inner) => (req) async {
          final res = await inner(req);
          return res.change(headers: {
            'content-security-policy': "default-src 'self' 'unsafe-inline' data: blob:; connect-src 'self'; frame-ancestors 'none'",
            'x-content-type-options': 'nosniff',
            'referrer-policy': 'no-referrer',
          });
        };

    final handler = const Pipeline().addMiddleware(security()).addHandler(r.call);
    final server = await io.serve(handler, InternetAddress.loopbackIPv4, 0, shared: false);
    return _instance = LoopbackServer._(server, token);
  }

  static int? _zim(CatalogItem? i) {
    final lib = ZimLib.instance;
    if (i == null || lib == null) return null;
    return _zimHandles[i.id] ??= lib.open(StoragePaths.instance.resolve(i.target));
  }

  static Database? _mb(CatalogItem? i) {
    if (i == null) return null;
    final path = StoragePaths.instance.resolve(i.target);
    if (!File(path).existsSync()) return null;
    return _mbtiles[i.id] ??= sqlite3.open(path, mode: OpenMode.readOnly);
  }

  Future<void> stop() async {
    await _server.close(force: true);
    for (final h in _zimHandles.values) {
      ZimLib.instance?.close(h);
    }
    for (final d in _mbtiles.values) {
      d.close();
    }
    _zimHandles.clear();
    _mbtiles.clear();
    _instance = null;
  }
}
