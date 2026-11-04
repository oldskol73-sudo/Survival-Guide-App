// The video database: links to YouTube tutorials, each filed under a library category and, where the subject matches,
// linked to the manuals in the library. The list ships inside the app, so browsing works with no signal; only
// playing a video needs the internet (and is blocked while the node is sealed).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../catalog/catalog_models.dart';

class VideoPdf {
  VideoPdf(this.path, this.title);
  final String path; // library-relative, forward slashes, same as CatalogItem.target
  final String title;
}

class VideoEntry {
  VideoEntry({required this.id, required this.title, required this.channel, required this.cat, required this.topic, required this.secs, required this.pdfs});
  final String id; // YouTube video id
  final String title;
  final String channel;
  final String cat; // library category id
  final String topic;
  final int secs;
  final List<VideoPdf> pdfs;

  Uri get url => Uri.https('www.youtube.com', '/watch', {'v': id});

  String get length {
    if (secs <= 0) return '';
    final m = secs ~/ 60, s = secs % 60;
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '$m:${s.toString().padLeft(2, '0')}';
  }

  factory VideoEntry.fromJson(Map<String, dynamic> j) => VideoEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        channel: j['channel'] as String,
        cat: j['cat'] as String,
        topic: j['topic'] as String,
        secs: (j['secs'] as num?)?.toInt() ?? 0,
        pdfs: [for (final p in (j['pdfs'] as List? ?? const [])) VideoPdf(p['path'] as String, p['title'] as String)],
      );
}

/// Display names for the library categories the videos are filed under.
const videoCategoryLabels = <String, String>{
  'water': 'Water',
  'food': 'Food and farming',
  'medical': 'Medical',
  'energy': 'Power and heat',
  'comms': 'Radio and navigation',
  'transport': 'Vehicles',
  'mechanical': 'Tools and repair',
  'carpentry': 'Shelter and building',
  'longterm': 'Preparedness and security',
};

class VideoDb {
  VideoDb(this.videos);
  final List<VideoEntry> videos;

  static VideoDb? _cached;

  static Future<VideoDb> load() async {
    if (_cached != null) return _cached!;
    final j = jsonDecode(await rootBundle.loadString('assets/catalog/videos.json')) as Map<String, dynamic>;
    return _cached = VideoDb([for (final v in j['videos'] as List) VideoEntry.fromJson(v as Map<String, dynamic>)]);
  }

  /// Category ids that have at least one video, in display order.
  List<String> get categories => [for (final c in videoCategoryLabels.keys) if (videos.any((v) => v.cat == c)) c];

  List<VideoEntry> search(String query, {String? cat, bool onlyWithManuals = false}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final v in videos)
        if ((cat == null || v.cat == cat) &&
            (!onlyWithManuals || v.pdfs.isNotEmpty) &&
            words.every((w) => v.title.toLowerCase().contains(w) || v.topic.toLowerCase().contains(w) || v.channel.toLowerCase().contains(w)))
          v
    ];
  }
}

/// Finds the library file a video points at: a catalog item first, then a PDF found on the device by the library scan.
CatalogItem? resolveVideoPdf(Catalog catalog, VideoPdf p) {
  for (final i in catalog.allItems) {
    if (i.target == p.path) return i;
  }
  for (final i in catalog.localItems) {
    if (i.target == p.path) return i;
  }
  return null;
}
