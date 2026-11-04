// Videos tab: browse and search the video database; each video shows the library manuals that cover the same subject.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../viewers/viewer_screens.dart';
import 'video_db.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final _query = TextEditingController();
  late final Future<VideoDb> _db = VideoDb.load();
  String? _cat;
  bool _onlyManuals = false;
  int _shown = 60;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _play(VideoEntry v) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AppSettings.instance.sealed) {
      messenger.showSnackBar(const SnackBar(content: Text('This node is sealed (air-gapped), so videos cannot play. Unseal it in Settings while you are online.')));
      return;
    }
    var ok = false;
    try {
      ok = await launchUrl(v.url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Could not open the video. Check that you are online.')));
  }

  void _openManual(VideoPdf p) {
    final item = resolveVideoPdf(Services.catalog, p);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That manual is not on this device yet. Add it from the Library tab.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(item: item)));
  }

  void _details(VideoEntry v) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${v.channel}${v.length.isEmpty ? '' : ' · ${v.length}'} · ${v.topic}', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _play(v);
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch on YouTube (needs internet)'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg, minimumSize: const Size.fromHeight(48)),
            ),
            if (v.pdfs.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Read the same topic offline', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
              const SizedBox(height: 6),
              for (final p in v.pdfs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.accent),
                  title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openManual(p);
                  },
                ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VideoDb>(
      future: _db,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load the video list: ${snap.error}')));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final db = snap.data!;
        final results = db.search(_query.text, cat: _cat, onlyWithManuals: _onlyManuals);
        final shown = results.take(_shown).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          const Text('Video tutorials', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Links to YouTube how-to videos, matched to the manuals in your library. Browsing works offline; playing needs internet.',
              style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() => _shown = 60),
            decoration: const InputDecoration(hintText: 'Search videos (water filter, canning, solar…)', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(label: const Text('All'), selected: _cat == null, onSelected: (_) => setState(() {
              _cat = null;
              _shown = 60;
            })),
            for (final c in db.categories)
              ChoiceChip(label: Text(videoCategoryLabels[c]!), selected: _cat == c, onSelected: (_) => setState(() {
                _cat = c;
                _shown = 60;
              })),
          ]),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only videos with a matching manual'),
            value: _onlyManuals,
            onChanged: (v) => setState(() {
              _onlyManuals = v;
              _shown = 60;
            }),
          ),
          Text('${results.length} videos', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 6),
          for (final v in shown)
            Card(
              child: ListTile(
                title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${v.channel}${v.length.isEmpty ? '' : ' · ${v.length}'} · ${v.topic}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: v.pdfs.isEmpty
                    ? const Icon(Icons.play_circle_outline, color: AppTheme.muted)
                    : const Badge(label: Text('PDF'), backgroundColor: AppTheme.accent, textColor: AppTheme.bg, child: Icon(Icons.play_circle_outline, color: AppTheme.accent)),
                onTap: () => _details(v),
              ),
            ),
          if (results.length > shown.length)
            TextButton(onPressed: () => setState(() => _shown += 60), child: Text('Show more (${results.length - shown.length} left)')),
        ]);
      },
    );
  }
}
