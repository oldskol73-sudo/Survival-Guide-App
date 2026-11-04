// Dev tool: cut a region out of a remote PMTiles archive into a local tile dump.
//
//   dart --packages=.dart_tool/package_config.json tool/pmtiles_extract.dart \
//        --url https://build.protomaps.com/20261103.pmtiles \
//        --bbox -77.99,38.84,-77.33,39.33 --minzoom 0 --maxzoom 14 --out tools/maps/loudoun
//
// Writes <out>.tiles (binary: z u8, x u32, y u32, length u32, data; little endian) and <out>.json (metadata).
// Then run  python tool/pack_mbtiles.py <out>  to produce the .mbtiles file the app reads.
// (The app itself uses lib/maps/mbtiles_sink.dart; this dump route exists only because the command line on a
// machine without a C compiler cannot load SQLite.)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:survival_node_mobile/maps/pmtiles.dart';

class DumpSink implements TileSink {
  DumpSink(this.base);
  final String base;
  late final IOSink _out;

  @override
  Future<void> begin(PmtilesHeader h, Map<String, dynamic> metadata, TileSelection s) async {
    _out = File('$base.tiles').openWrite();
    await File('$base.json').writeAsString(jsonEncode({
      'metadata': metadata,
      'bounds': [s.west, s.south, s.east, s.north],
      'minzoom': s.minZoom,
      'maxzoom': s.maxZoom,
      'tileCompression': h.tileCompression,
    }));
  }

  @override
  Future<void> add(int z, int x, int y, Uint8List data) async {
    // A fresh header per tile: IOSink keeps a reference to what it is given until it is written.
    final head = ByteData(13)
      ..setUint8(0, z)
      ..setUint32(1, x, Endian.little)
      ..setUint32(5, y, Endian.little)
      ..setUint32(9, data.length, Endian.little);
    _out.add(head.buffer.asUint8List());
    _out.add(data);
  }

  @override
  Future<void> finish() async => _out.close();
}

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final url = arg('url'), file = arg('file'), bbox = arg('bbox'), out = arg('out');
  if ((url == null && file == null) || bbox == null || out == null) {
    stderr.writeln('usage: (--url <https pmtiles url> | --file <local .pmtiles>) --bbox west,south,east,north [--minzoom 0] [--maxzoom 14] --out <path without extension>');
    exit(2);
  }
  final b = bbox.split(',').map(double.parse).toList();
  final selection = TileSelection(
    west: b[0],
    south: b[1],
    east: b[2],
    north: b[3],
    minZoom: int.parse(arg('minzoom') ?? '0'),
    maxZoom: int.parse(arg('maxzoom') ?? '14'),
  );
  stdout.writeln('Region needs ${selection.tileCount} tiles.');

  final RangeReader read;
  final void Function() close;
  int Function() requests = () => 0;
  int Function() received = () => 0;
  if (file != null) {
    final r = FileRangeReader(file);
    read = r.call;
    close = r.close;
  } else {
    final r = HttpRangeReader(url!);
    read = r.call;
    close = r.close;
    requests = () => r.requests;
    received = () => r.bytesReceived;
  }
  final started = DateTime.now();
  var lastPrint = DateTime.fromMillisecondsSinceEpoch(0);
  final extractor = PmtilesExtractor(read, onProgress: (p) {
    final now = DateTime.now();
    if (now.difference(lastPrint).inMilliseconds < 1000 && p.done != p.total) return;
    lastPrint = now;
    stdout.writeln('  ${p.phase}${p.total > 0 ? ' ${p.done}/${p.total}' : (p.done > 0 ? ' (${p.done} leaf dirs)' : '')}');
  });
  try {
    final stats = await extractor.extract(selection, DumpSink(out));
    final secs = DateTime.now().difference(started).inMilliseconds / 1000;
    stdout.writeln('Done in ${secs.toStringAsFixed(1)}s: ${stats.tiles} tiles (${stats.distinctBlobs} distinct), '
        '${(stats.tileBytes / 1048576).toStringAsFixed(1)} MB of tile data, ${requests()} requests, '
        '${(received() / 1048576).toStringAsFixed(1)} MB downloaded, ${stats.leafDirectories} leaf directories.');
  } finally {
    close();
  }
}
