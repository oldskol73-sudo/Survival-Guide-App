// Plans and runs an offline-map download: "a circle around the user's position" becomes a bounding box, the
// source file is located, and the region is cut out into library/11_Maps/region.mbtiles.
// This is Stage A work (it needs the network) and is blocked once the node is sealed.

import 'dart:io';
import 'dart:math' as math;

import '../catalog/catalog_models.dart';
import 'mbtiles_sink.dart';
import 'pmtiles.dart';

/// How much detail to download. Higher zoom = street level, and much bigger files.
enum MapDetail {
  roads('Roads and towns', 12, 'Main roads, towns and water. Smallest download.'),
  streets('Streets and buildings', 14, 'Every street and building footprint. About 5x larger.');

  const MapDetail(this.label, this.maxZoom, this.blurb);
  final String label;
  final int maxZoom;
  final String blurb;
}

class MapPlan {
  MapPlan({required this.lat, required this.lon, required this.radiusKm, required this.detail});
  final double lat, lon, radiusKm;
  final MapDetail detail;

  TileSelection get selection {
    final dLat = radiusKm / 110.574;
    final dLon = radiusKm / (111.320 * math.cos(lat.clamp(-80.0, 80.0) * math.pi / 180));
    return TileSelection(
      west: (lon - dLon).clamp(-179.99, 179.99),
      south: (lat - dLat).clamp(-85.0, 85.0),
      east: (lon + dLon).clamp(-179.99, 179.99),
      north: (lat + dLat).clamp(-85.0, 85.0),
      minZoom: 0,
      maxZoom: detail.maxZoom,
    );
  }

  /// Rough download size, from measured averages of a real extract (suburban Virginia). Dense cities run larger.
  int get estimatedBytes {
    const avgKb = {0: 65, 1: 70, 2: 62, 3: 55, 4: 50, 5: 30, 6: 85, 7: 220, 8: 190, 9: 200, 10: 120, 11: 56, 12: 29, 13: 16, 14: 9, 15: 6};
    final s = selection;
    var bytes = 0.0;
    for (var z = s.minZoom; z <= s.maxZoom; z++) {
      final n = (TileSelection.lonToX(s.east, z) - TileSelection.lonToX(s.west, z) + 1) * (TileSelection.latToY(s.south, z) - TileSelection.latToY(s.north, z) + 1);
      bytes += n * (avgKb[z] ?? 8) * 1024;
    }
    return bytes.round();
  }
}

class MapSourceChoice {
  MapSourceChoice(this.url, this.label, {required this.hosted});
  final Uri url;
  final String label;

  /// True for a file we host; false for the public fallback.
  final bool hosted;
}

class MapDownloadResult {
  MapDownloadResult(this.stats, this.bytesOnDisk, this.sourceLabel);
  final ExtractStats stats;
  final int bytesOnDisk;
  final String sourceLabel;
}

class MapDownloader {
  /// Locates a map file for the plan's centre: our hosted region covering the point first, then the public
  /// fallback (newest daily world file, walking back day by day).
  static Future<MapSourceChoice?> findSource(MapSource source, double lat, double lon) async {
    final client = HttpClient()..autoUncompress = false;
    Future<bool> alive(Uri url) async {
      try {
        final req = await client.headUrl(url).timeout(const Duration(seconds: 20));
        final res = await req.close().timeout(const Duration(seconds: 20));
        await res.drain<void>();
        return res.statusCode == 200;
      } catch (_) {
        return false; // network hiccup: treat as unavailable and try the next candidate
      }
    }

    try {
      for (final r in source.regionsFor(lat, lon)) {
        final url = Uri.parse(r.url);
        if (await alive(url)) return MapSourceChoice(url, r.name, hosted: true);
      }
      final today = DateTime.now().toUtc();
      for (var back = 0; back < source.searchDays; back++) {
        final day = DateTime.utc(today.year, today.month, today.day).subtract(Duration(days: back));
        final url = source.urlFor(day);
        if (await alive(url)) return MapSourceChoice(url, 'Public world map ${day.toIso8601String().substring(0, 10)}', hosted: false);
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads the plan's region into [targetPath] (written to a temp file first, then moved into place).
  static Future<MapDownloadResult> download({
    required MapSource source,
    required MapPlan plan,
    required String targetPath,
    void Function(ExtractProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    onProgress?.call(ExtractProgress('Finding the latest map', 0, 0));
    final found = await findSource(source, plan.lat, plan.lon);
    if (found == null) throw PmtilesException('Could not reach a map source. Check your connection and try again.');
    final url = found.url;

    final temp = '$targetPath.part';
    await File(targetPath).parent.create(recursive: true); // fresh installs have no 11_Maps folder yet
    final sink = MbtilesSink(temp);
    final reader = HttpRangeReader(url.toString());
    try {
      final extractor = PmtilesExtractor(reader.call, onProgress: onProgress, isCancelled: isCancelled);
      final stats = await extractor.extract(plan.selection, sink);
      if (stats.tiles == 0) throw PmtilesException('No map data found for that area.');
      final target = File(targetPath);
      if (await target.exists()) await target.delete();
      await File(temp).rename(targetPath);
      return MapDownloadResult(stats, await File(targetPath).length(), found.label);
    } catch (_) {
      await sink.abort();
      rethrow;
    } finally {
      reader.close();
    }
  }
}
