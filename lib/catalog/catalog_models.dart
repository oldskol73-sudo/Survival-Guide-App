// Typed model for assets/catalog/categories.json, with strict validation.
// The catalog is the only place URLs enter the app, so every field is checked.

import 'dart:convert';

enum CategoryKind { pdf, zim, map, model }

class CatalogException implements Exception {
  CatalogException(this.message);
  final String message;
  @override
  String toString() => 'CatalogException: $message';
}

final _sha256Re = RegExp(r'^[a-f0-9]{64}$');
final _idRe = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');

class CatalogItem {
  CatalogItem({
    required this.id,
    required this.title,
    required this.url,
    required this.mirrors,
    required this.sha256,
    required this.sha256Url,
    required this.sizeBytes,
    required this.target,
    required this.license,
    required this.index,
    required this.categoryId,
    required this.kind,
    this.tier,
    this.sourceUrl,
  });

  final String id;
  final String title;
  final Uri url;
  final List<Uri> mirrors;
  final String? sha256; // expected lowercase hex; null = trust on first use
  final Uri? sha256Url; // sidecar "<hash>  <name>" file (Kiwix style)
  final int? sizeBytes; // used for the disk-space pre-flight when known
  final String target; // relative path; "@models/..." = private model dir
  final String license;
  final bool index; // run FTS + embeddings after verification
  final String categoryId;
  final CategoryKind kind;
  /// Official page of the agency that published the item (for example a .gov address). Shown to the user as a link.
  final Uri? sourceUrl;
  final String? tier; // models only: "small" | "large"

  /// True for a PDF found on disk by the local-library scan (not downloaded through the catalog).
  bool get isLocal => id.startsWith('local-');
  bool get isPlaceholder => url.toString().startsWith('[') || url.toString().contains('YYYY-MM');
  bool get isPrivateModel => target.startsWith('@models/');

  factory CatalogItem.fromJson(Map<String, dynamic> j, String categoryId, CategoryKind kind) {
    final id = j['id'] as String? ?? '';
    if (!_idRe.hasMatch(id)) throw CatalogException('bad item id "$id"');

    final target = j['target'] as String? ?? '';
    // Reject traversal, absolute paths and backslashes: the target is joined onto a sandbox root.
    if (target.isEmpty || target.startsWith('/') || target.contains('..') || target.contains('\\')) {
      throw CatalogException('item $id: unsafe target "$target"');
    }

    final sha = (j['sha256'] as String?)?.toLowerCase();
    if (sha != null && !_sha256Re.hasMatch(sha)) throw CatalogException('item $id: sha256 must be 64 hex chars');

    Uri parseUrl(String raw) {
      if (raw.startsWith('[')) return Uri(path: raw); // documented placeholder; never enqueued
      final u = Uri.parse(raw);
      if (u.scheme != 'https') throw CatalogException('item $id: only https URLs are allowed ($raw)');
      return u;
    }

    return CatalogItem(
      id: id,
      title: j['title'] as String? ?? id,
      url: parseUrl(j['url'] as String),
      mirrors: [for (final m in (j['mirrors'] as List? ?? const [])) parseUrl(m as String)],
      sha256: sha,
      sha256Url: j['sha256Url'] == null ? null : parseUrl(j['sha256Url'] as String),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
      target: target,
      license: j['license'] as String? ?? 'unknown',
      index: j['index'] as bool? ?? false,
      categoryId: categoryId,
      kind: kind,
      tier: j['tier'] as String?,
      sourceUrl: j['sourceUrl'] == null ? null : parseUrl(j['sourceUrl'] as String),
    );
  }
}

/// A map file we host ourselves, covering a rectangle. The app reads just the part it needs with HTTP range requests.
class MapRegion {
  MapRegion({required this.id, required this.name, required this.url, required this.west, required this.south, required this.east, required this.north});
  final String id;
  final String name;

  /// https URL of a PMTiles file, or a "[...]" placeholder until the file is published.
  final String url;
  final double west, south, east, north;

  bool get isPublished => !url.startsWith('[');
  bool contains(double lat, double lon) => lat >= south && lat <= north && lon >= west && lon <= east;

  factory MapRegion.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    if (!_idRe.hasMatch(id)) throw CatalogException('bad map region id "$id"');
    final url = j['url'] as String? ?? '';
    if (!url.startsWith('[') && Uri.tryParse(url)?.scheme != 'https') throw CatalogException('map region $id: only https URLs are allowed');
    final b = [for (final v in (j['bbox'] as List? ?? const [])) (v as num).toDouble()];
    if (b.length != 4 || b[0] >= b[2] || b[1] >= b[3]) throw CatalogException('map region $id: bbox must be [west, south, east, north]');
    return MapRegion(id: id, name: j['name'] as String? ?? id, url: url, west: b[0], south: b[1], east: b[2], north: b[3]);
  }
}

/// Where region maps come from. [regions] are files we host, tried first. [urlTemplate] is a public fallback
/// for places we do not cover: it must be https and contain {yyyymmdd}, because that source publishes a dated
/// world file every day, so the app tries today and walks back up to [searchDays] days.
class MapSource {
  MapSource({required this.urlTemplate, required this.searchDays, this.regions = const []});
  final String urlTemplate;
  final int searchDays;
  final List<MapRegion> regions;

  /// Published hosted regions whose rectangle contains the point.
  List<MapRegion> regionsFor(double lat, double lon) => [for (final r in regions) if (r.isPublished && r.contains(lat, lon)) r];

  factory MapSource.fromJson(Map<String, dynamic> j) {
    final t = j['urlTemplate'] as String? ?? '';
    final u = Uri.tryParse(t.replaceAll('{yyyymmdd}', '20000101'));
    if (u == null || u.scheme != 'https' || !t.contains('{yyyymmdd}')) {
      throw CatalogException('mapSource.urlTemplate must be an https URL containing {yyyymmdd}');
    }
    return MapSource(
      urlTemplate: t,
      searchDays: ((j['searchDays'] as num?)?.toInt() ?? 7).clamp(1, 30),
      regions: [for (final r in (j['regions'] as List? ?? const [])) MapRegion.fromJson(r as Map<String, dynamic>)],
    );
  }

  Uri urlFor(DateTime utcDay) {
    final d = '${utcDay.year.toString().padLeft(4, '0')}${utcDay.month.toString().padLeft(2, '0')}${utcDay.day.toString().padLeft(2, '0')}';
    return Uri.parse(urlTemplate.replaceAll('{yyyymmdd}', d));
  }
}

class Category {
  Category({
    required this.id,
    required this.code,
    required this.title,
    required this.dir,
    required this.kind,
    required this.defaultEnabled,
    required this.subdirs,
    required this.items,
    this.mapSource,
  });

  final String id;
  final String code;
  final String title;
  final String dir;
  final CategoryKind kind;
  final bool defaultEnabled;
  final List<String> subdirs;
  final List<CatalogItem> items;
  final MapSource? mapSource; // map categories only

  factory Category.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final kind = CategoryKind.values.byName(j['kind'] as String);
    return Category(
      id: id,
      code: j['code'] as String,
      title: j['title'] as String,
      dir: j['dir'] as String,
      kind: kind,
      defaultEnabled: j['defaultEnabled'] as bool? ?? true,
      subdirs: [for (final s in (j['subdirs'] as List? ?? const [])) s as String],
      items: [for (final i in (j['items'] as List? ?? const [])) CatalogItem.fromJson(i as Map<String, dynamic>, id, kind)],
      mapSource: j['mapSource'] == null ? null : MapSource.fromJson(j['mapSource'] as Map<String, dynamic>),
    );
  }
}

class Catalog {
  Catalog({required this.schemaVersion, required this.catalogId, required this.categories});

  final int schemaVersion;
  final String catalogId;
  final List<Category> categories;

  Iterable<CatalogItem> get allItems => categories.expand((c) => c.items);

  /// PDFs found on disk by the local-library scan. Kept apart from [categories] so the download UI is unaffected.
  final List<CatalogItem> localItems = [];

  CatalogItem? itemById(String id) {
    for (final i in allItems) {
      if (i.id == id) return i;
    }
    for (final i in localItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  static Catalog parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, dynamic>;
    final v = j['schemaVersion'] as int? ?? 0;
    if (v != 1) throw CatalogException('unsupported schemaVersion $v');
    final cats = [for (final c in j['categories'] as List) Category.fromJson(c as Map<String, dynamic>)];
    final ids = <String>{};
    for (final i in cats.expand((c) => c.items)) {
      if (!ids.add(i.id)) throw CatalogException('duplicate item id ${i.id}');
    }
    return Catalog(schemaVersion: v, catalogId: j['catalogId'] as String, categories: cats);
  }
}
