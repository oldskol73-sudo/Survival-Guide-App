// PMTiles v3 reader and region extractor. Pure Dart (dart:io only), so it runs in the app and from the
// command line.
//
// A PMTiles file is one huge archive of map tiles with an index at its end. Because the index lets us find
// any tile by byte range, we can pull a single region out of a multi-gigabyte world map with ordinary HTTP
// `Range` requests, downloading only the tiles inside the region. Spec: https://github.com/protomaps/PMTiles
//
// Offline use: the extractor only runs while the user is downloading a map (Stage A). Everything it
// produces is read later from a local file, with no network.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Reads [length] bytes starting at [offset]. Implementations: [HttpRangeReader] (remote) or a local file.
typedef RangeReader = Future<Uint8List> Function(int offset, int length);

/// Thrown when the caller's `isCancelled` callback returns true.
class PmtilesCancelled implements Exception {
  @override
  String toString() => 'PmtilesCancelled';
}

class PmtilesException implements Exception {
  PmtilesException(this.message);
  final String message;
  @override
  String toString() => 'PmtilesException: $message';
}

// ---------------------------------------------------------------------------------------------- header

class PmtilesHeader {
  PmtilesHeader._({
    required this.rootOffset,
    required this.rootLength,
    required this.metadataOffset,
    required this.metadataLength,
    required this.leafOffset,
    required this.leafLength,
    required this.dataOffset,
    required this.dataLength,
    required this.addressedTiles,
    required this.tileEntries,
    required this.tileContents,
    required this.clustered,
    required this.internalCompression,
    required this.tileCompression,
    required this.tileType,
    required this.minZoom,
    required this.maxZoom,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  static const byteLength = 127;

  final int rootOffset, rootLength, metadataOffset, metadataLength, leafOffset, leafLength, dataOffset, dataLength;
  final int addressedTiles, tileEntries, tileContents;
  final bool clustered;

  /// 0 unknown, 1 none, 2 gzip, 3 brotli, 4 zstd.
  final int internalCompression, tileCompression;

  /// 1 = Mapbox Vector Tile, 2 png, 3 jpeg, 4 webp, 5 avif.
  final int tileType;
  final int minZoom, maxZoom;
  final double minLon, minLat, maxLon, maxLat;

  factory PmtilesHeader.parse(Uint8List b) {
    if (b.length < byteLength) throw PmtilesException('Header too short (${b.length} bytes)');
    if (String.fromCharCodes(b.sublist(0, 7)) != 'PMTiles') throw PmtilesException('Not a PMTiles file');
    if (b[7] != 3) throw PmtilesException('Unsupported PMTiles version ${b[7]} (need 3)');
    final d = ByteData.sublistView(b);
    int u64(int o) => d.getUint64(o, Endian.little);
    double deg(int o) => d.getInt32(o, Endian.little) / 1e7;
    return PmtilesHeader._(
      rootOffset: u64(8),
      rootLength: u64(16),
      metadataOffset: u64(24),
      metadataLength: u64(32),
      leafOffset: u64(40),
      leafLength: u64(48),
      dataOffset: u64(56),
      dataLength: u64(64),
      addressedTiles: u64(72),
      tileEntries: u64(80),
      tileContents: u64(88),
      clustered: b[96] == 1,
      internalCompression: b[97],
      tileCompression: b[98],
      tileType: b[99],
      minZoom: b[100],
      maxZoom: b[101],
      minLon: deg(102),
      minLat: deg(106),
      maxLon: deg(110),
      maxLat: deg(114),
    );
  }
}

// ----------------------------------------------------------------------------------------- directories

class PmtilesEntry {
  const PmtilesEntry(this.tileId, this.offset, this.length, this.runLength);
  final int tileId;
  final int offset;
  final int length;

  /// 0 = this entry points at a leaf directory; >0 = tile data, shared by [runLength] consecutive tile ids.
  final int runLength;
}

Uint8List decompressInternal(Uint8List bytes, int compression) {
  switch (compression) {
    case 1:
      return bytes;
    case 2:
      return Uint8List.fromList(gzip.decode(bytes));
    default:
      throw PmtilesException('Unsupported internal compression $compression (only none and gzip)');
  }
}

/// Decodes a (decompressed) directory: varint count, then delta tile ids, run lengths, lengths, offsets.
List<PmtilesEntry> decodeDirectory(Uint8List b) {
  var pos = 0;
  int varint() {
    var result = 0, shift = 0;
    while (true) {
      if (pos >= b.length) throw PmtilesException('Directory ended inside a varint');
      final byte = b[pos++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return result;
      shift += 7;
      if (shift > 63) throw PmtilesException('Varint too long');
    }
  }

  final n = varint();
  final ids = List<int>.filled(n, 0);
  var last = 0;
  for (var i = 0; i < n; i++) {
    last += varint();
    ids[i] = last;
  }
  final runs = List<int>.generate(n, (_) => varint());
  final lengths = List<int>.generate(n, (_) => varint());
  final out = <PmtilesEntry>[];
  var prevOffset = 0, prevLength = 0;
  for (var i = 0; i < n; i++) {
    final v = varint();
    final offset = (v == 0 && i > 0) ? prevOffset + prevLength : v - 1;
    out.add(PmtilesEntry(ids[i], offset, lengths[i], runs[i]));
    prevOffset = offset;
    prevLength = lengths[i];
  }
  return out;
}

// ------------------------------------------------------------------------------------- tile id (Hilbert)

void _rotate(int n, List<int> xy, int rx, int ry) {
  if (ry == 0) {
    if (rx == 1) {
      xy[0] = n - 1 - xy[0];
      xy[1] = n - 1 - xy[1];
    }
    final t = xy[0];
    xy[0] = xy[1];
    xy[1] = t;
  }
}

/// Tile id = number of tiles on all lower zooms + position along the Hilbert curve on this zoom.
int zxyToTileId(int z, int x, int y) {
  if (z > 26) throw PmtilesException('Zoom $z too large');
  final n = 1 << z;
  if (x < 0 || y < 0 || x >= n || y >= n) throw PmtilesException('Tile $z/$x/$y out of range');
  final acc = ((1 << (2 * z)) - 1) ~/ 3; // (4^z - 1) / 3
  var d = 0;
  final xy = [x, y];
  for (var s = n >> 1; s > 0; s >>= 1) {
    final rx = (xy[0] & s) > 0 ? 1 : 0;
    final ry = (xy[1] & s) > 0 ? 1 : 0;
    d += s * s * ((3 * rx) ^ ry);
    _rotate(s, xy, rx, ry);
  }
  return acc + d;
}

/// Inverse of [zxyToTileId]: returns [z, x, y].
List<int> tileIdToZxy(int id) {
  var acc = 0;
  for (var z = 0; z < 27; z++) {
    final count = 1 << (2 * z);
    if (acc + count > id) {
      final n = 1 << z;
      var t = id - acc;
      final xy = [0, 0];
      for (var s = 1; s < n; s <<= 1) {
        final rx = 1 & (t ~/ 2);
        final ry = 1 & (t ^ rx);
        _rotate(s, xy, rx, ry);
        xy[0] += s * rx;
        xy[1] += s * ry;
        t ~/= 4;
      }
      return [z, xy[0], xy[1]];
    }
    acc += count;
  }
  throw PmtilesException('Tile id $id too large');
}

// ----------------------------------------------------------------------------------------- selection

/// A rectangle (degrees) and zoom range to extract.
class TileSelection {
  TileSelection({required this.west, required this.south, required this.east, required this.north, required this.minZoom, required this.maxZoom}) {
    if (west >= east || south >= north) throw ArgumentError('Empty bounding box');
    if (minZoom < 0 || maxZoom < minZoom || maxZoom > 22) throw ArgumentError('Bad zoom range');
  }

  final double west, south, east, north;
  final int minZoom, maxZoom;

  static int lonToX(double lon, int z) => (((lon + 180) / 360) * (1 << z)).floor().clamp(0, (1 << z) - 1);

  static int latToY(double lat, int z) {
    final l = lat.clamp(-85.0511287798, 85.0511287798) * math.pi / 180;
    final merc = math.log(math.tan(l) + 1 / math.cos(l));
    return (((1 - merc / math.pi) / 2) * (1 << z)).floor().clamp(0, (1 << z) - 1);
  }

  /// Number of tiles in the selection, computed without building the list.
  int get tileCount {
    var n = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      n += (lonToX(east, z) - lonToX(west, z) + 1) * (latToY(south, z) - latToY(north, z) + 1);
    }
    return n;
  }

  /// Sorted tile ids of every tile in the selection.
  List<int> buildIds({int limit = 4000000}) {
    if (tileCount > limit) throw PmtilesException('Region too large: $tileCount tiles (limit $limit). Use a smaller area or lower max zoom.');
    final ids = <int>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final x0 = lonToX(west, z), x1 = lonToX(east, z);
      final y0 = latToY(north, z), y1 = latToY(south, z);
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          ids.add(zxyToTileId(z, x, y));
        }
      }
    }
    ids.sort();
    return ids;
  }
}

// ------------------------------------------------------------------------------------------- network

/// Range reader over HTTPS. HTTPS only: the app never opens plain-HTTP connections to remote hosts.
class HttpRangeReader {
  HttpRangeReader(String url, {this.retries = 3, this.timeout = const Duration(seconds: 45)})
      : _uri = Uri.parse(url),
        _client = HttpClient()..autoUncompress = false {
    if (_uri.scheme != 'https') throw PmtilesException('Only https URLs are allowed');
  }

  final Uri _uri;
  final HttpClient _client;
  final int retries;
  final Duration timeout;
  int requests = 0;
  int bytesReceived = 0;

  Future<Uint8List> call(int offset, int length) async {
    if (length <= 0) return Uint8List(0);
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        requests++;
        final req = await _client.getUrl(_uri).timeout(timeout);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-${offset + length - 1}');
        req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final res = await req.close().timeout(timeout);
        if (res.statusCode != 206) {
          await res.drain<void>();
          throw PmtilesException('Server did not honour the range request (HTTP ${res.statusCode})');
        }
        final bb = BytesBuilder(copy: false);
        await for (final chunk in res.timeout(timeout)) {
          bb.add(chunk);
        }
        final bytes = bb.takeBytes();
        if (bytes.length != length) throw PmtilesException('Short read: wanted $length bytes, got ${bytes.length}');
        bytesReceived += bytes.length;
        return bytes;
      } catch (e) {
        lastError = e;
        if (e is PmtilesException && e.message.contains('did not honour')) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw PmtilesException('Download failed after ${retries + 1} attempts: $lastError');
  }

  void close() => _client.close(force: true);
}

/// Range reader over a local file (tests, and maps already on the device).
class FileRangeReader {
  FileRangeReader(String path) : _file = File(path).openSync();
  final RandomAccessFile _file;

  Future<Uint8List> call(int offset, int length) async {
    _file.setPositionSync(offset);
    final bytes = _file.readSync(length);
    if (bytes.length != length) throw PmtilesException('Short read from file: wanted $length bytes, got ${bytes.length}');
    return bytes;
  }

  void close() => _file.closeSync();
}

// --------------------------------------------------------------------------------------------- extract

/// Receives the extracted tiles. Tiles arrive in XYZ coordinates (y = 0 at the top) with their original
/// compression (gzip for Protomaps).
abstract class TileSink {
  Future<void> begin(PmtilesHeader header, Map<String, dynamic> metadata, TileSelection selection);
  Future<void> add(int z, int x, int y, Uint8List data);
  Future<void> finish();
}

class ExtractProgress {
  ExtractProgress(this.phase, this.done, this.total);
  final String phase;
  final int done;
  final int total;
}

class ExtractStats {
  int tiles = 0;
  int distinctBlobs = 0;
  int tileBytes = 0;
  int leafDirectories = 0;
}

class _Pick {
  _Pick(this.tileId, this.runLength, this.offset, this.length);
  final int tileId, runLength, offset, length;
}

class PmtilesExtractor {
  PmtilesExtractor(this.read, {this.onProgress, this.isCancelled, this.concurrency = 4, this.maxGap = 64 * 1024, this.maxBatch = 8 * 1024 * 1024});

  final RangeReader read;
  final void Function(ExtractProgress)? onProgress;
  final bool Function()? isCancelled;
  final int concurrency;

  /// Neighbouring tiles closer than this are fetched in one request, trading a little waste for fewer requests.
  final int maxGap;
  final int maxBatch;

  Future<PmtilesHeader> readHeader() async => PmtilesHeader.parse(await read(0, PmtilesHeader.byteLength));

  Future<Map<String, dynamic>> readMetadata(PmtilesHeader h) async {
    if (h.metadataLength == 0) return {};
    final raw = decompressInternal(await read(h.metadataOffset, h.metadataLength), h.internalCompression);
    return jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
  }

  Future<ExtractStats> extract(TileSelection selection, TileSink sink) async {
    final stats = ExtractStats();
    final header = await readHeader();
    if (header.tileType != 1) throw PmtilesException('Not a vector-tile archive (type ${header.tileType})');
    if (selection.maxZoom > header.maxZoom) {
      throw PmtilesException('Archive only goes to zoom ${header.maxZoom}; asked for ${selection.maxZoom}');
    }
    onProgress?.call(ExtractProgress('Reading index', 0, 0));
    final metadata = await readMetadata(header);
    final wanted = selection.buildIds();

    int lowerBound(int v) {
      var lo = 0, hi = wanted.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (wanted[mid] < v) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo;
    }

    /// True if any wanted tile id lies in [a, b).
    bool anyWanted(int a, int b) {
      final i = lowerBound(a);
      return i < wanted.length && wanted[i] < b;
    }

    // 1. Walk the directory tree, keeping only branches that can contain wanted tiles.
    final picks = <_Pick>[];
    Future<void> walk(Uint8List dirBytes, int endId) async {
      final entries = decodeDirectory(decompressInternal(dirBytes, header.internalCompression));
      for (var i = 0; i < entries.length; i++) {
        if (isCancelled?.call() ?? false) throw PmtilesCancelled();
        final e = entries[i];
        if (e.runLength == 0) {
          final end = i + 1 < entries.length ? entries[i + 1].tileId : endId;
          if (!anyWanted(e.tileId, end)) continue;
          stats.leafDirectories++;
          onProgress?.call(ExtractProgress('Reading index', stats.leafDirectories, 0));
          await walk(await read(header.leafOffset + e.offset, e.length), end);
        } else if (anyWanted(e.tileId, e.tileId + e.runLength)) {
          picks.add(_Pick(e.tileId, e.runLength, header.dataOffset + e.offset, e.length));
        }
      }
    }

    await walk(await read(header.rootOffset, header.rootLength), 1 << 62);
    picks.sort((a, b) => a.offset.compareTo(b.offset));

    // 2. Group nearby tiles into batches, then download the batches.
    final batches = <List<_Pick>>[];
    var current = <_Pick>[];
    var currentEnd = 0, currentStart = 0;
    for (final p in picks) {
      final fits = current.isNotEmpty && p.offset - currentEnd <= maxGap && (p.offset + p.length - currentStart) <= maxBatch;
      if (!fits && current.isNotEmpty) {
        batches.add(current);
        current = <_Pick>[];
      }
      if (current.isEmpty) currentStart = p.offset;
      current.add(p);
      currentEnd = p.offset + p.length;
    }
    if (current.isNotEmpty) batches.add(current);

    await sink.begin(header, metadata, selection);

    var nextBatch = 0, doneBatches = 0;
    Future<void> sinkLock = Future<void>.value(); // keeps sink writes in order, one at a time

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) throw PmtilesCancelled();
        final index = nextBatch++;
        if (index >= batches.length) return;
        final batch = batches[index];
        final start = batch.first.offset;
        final end = batch.last.offset + batch.last.length;
        final bytes = await read(start, end - start);
        final writes = <(int, int, int, Uint8List)>[];
        for (final p in batch) {
          final blob = Uint8List.sublistView(bytes, p.offset - start, p.offset - start + p.length);
          stats.distinctBlobs++;
          for (var i = lowerBound(p.tileId); i < wanted.length && wanted[i] < p.tileId + p.runLength; i++) {
            final zxy = tileIdToZxy(wanted[i]);
            writes.add((zxy[0], zxy[1], zxy[2], blob));
            stats.tiles++;
            stats.tileBytes += blob.length;
          }
        }
        sinkLock = sinkLock.then((_) async {
          for (final w in writes) {
            await sink.add(w.$1, w.$2, w.$3, w.$4);
          }
        });
        await sinkLock;
        doneBatches++;
        onProgress?.call(ExtractProgress('Downloading tiles', doneBatches, batches.length));
      }
    }

    await Future.wait([for (var i = 0; i < math.max(1, concurrency); i++) worker()]);
    await sinkLock;
    await sink.finish();
    return stats;
  }
}
