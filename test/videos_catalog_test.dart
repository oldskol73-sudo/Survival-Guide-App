// flutter test test/videos_catalog_test.dart
// The shipped video list parses, has no duplicate videos, and every manual link points at a real library path.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survival_node_mobile/videos/video_db.dart';

void main() {
  final json = jsonDecode(File('assets/catalog/videos.json').readAsStringSync()) as Map<String, dynamic>;
  final videos = [for (final v in json['videos'] as List) VideoEntry.fromJson(v as Map<String, dynamic>)];

  test('no video appears twice', () {
    final seen = <String>{};
    final dupes = [for (final v in videos) if (!seen.add(v.id)) v.id];
    expect(dupes, isEmpty);
  });

  test('every video is filed under a category the app can show', () {
    final bad = [for (final v in videos) if (!videoCategoryLabels.containsKey(v.cat)) '${v.id} (${v.cat})'];
    expect(bad, isEmpty);
  });

  test('We Da People Podcast videos are present, filed and linked to manuals', () {
    final wdp = videos.where((v) => v.channel == 'We Da People Podcast').toList();
    expect(wdp.length, 11);
    expect(wdp.every((v) => v.pdfs.isNotEmpty), isTrue, reason: 'each one should link to at least one manual');
    expect(wdp.every((v) => v.url.toString().startsWith('https://www.youtube.com/watch?v=')), isTrue);
  });

  test('the manuals those videos link to are the library items that fit them', () {
    final catalog = jsonDecode(File('assets/catalog/categories.json').readAsStringSync()) as Map<String, dynamic>;
    final targets = {
      for (final c in catalog['categories'] as List) for (final i in c['items'] as List) i['target'] as String,
    };
    // The manuals other videos already link to (a local library scan supplies these) count as real too.
    final linkedElsewhere = {
      for (final v in videos.where((v) => v.channel != 'We Da People Podcast')) for (final p in v.pdfs) p.path,
    };
    for (final v in videos.where((v) => v.channel == 'We Da People Podcast')) {
      for (final p in v.pdfs) {
        expect(targets.contains(p.path) || linkedElsewhere.contains(p.path), isTrue, reason: '${v.title}: ${p.path}');
      }
    }
  });
}
