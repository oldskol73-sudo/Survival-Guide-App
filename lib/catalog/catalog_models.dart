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
  final String? tier; // models only: "small" | "large"

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
    );
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
  });

  final String id;
  final String code;
  final String title;
  final String dir;
  final CategoryKind kind;
  final bool defaultEnabled;
  final List<String> subdirs;
  final List<CatalogItem> items;

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
    );
  }
}

class Catalog {
  Catalog({required this.schemaVersion, required this.catalogId, required this.categories});

  final int schemaVersion;
  final String catalogId;
  final List<Category> categories;

  Iterable<CatalogItem> get allItems => categories.expand((c) => c.items);

  CatalogItem? itemById(String id) {
    for (final i in allItems) {
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
