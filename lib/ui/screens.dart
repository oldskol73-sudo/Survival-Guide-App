// App shell and the four main screens: Home (guided tasks), Library (Stage A sync), Search (FTS5), Settings.

import 'package:flutter/material.dart';

import '../airgap/airgap_banner.dart';
import '../airgap/airgap_monitor.dart';
import '../airgap/network_lockdown.dart';
import '../catalog/catalog_models.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../downloads/download_engine.dart';
import '../family/family_screen.dart';
import '../home/field_guide_screen.dart';
import '../home/gear_screen.dart';
import '../home/home_screen.dart';
import '../home/tour_screen.dart';
import 'about_screen.dart';
import '../maps/maps_screen.dart';
import '../videos/videos_screen.dart';
import 'masthead.dart';
import '../search/fts_index.dart';
import 'my_documents_screen.dart';
import 'wild_plants_screen.dart';
import '../viewers/viewer_screens.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // First launch only: walk the user through the app once. Replayable from Settings.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !AppSettings.instance.tourSeen) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TourScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: (i) => setState(() => _tab = i)),
      const LibraryScreen(),
      const VideosScreen(),
      const FamilyScreen(),
      const AirGapGate(featureName: 'library search', child: SearchScreen()),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: Column(children: [const Masthead(), Expanded(child: pages[_tab])])),
      // Six tabs share the width, so the labels must not grow with the system text size: at a large size
      // "Settings" wrapped onto two lines and pushed its picture out of line with the others.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          height: 88,
          indicatorColor: Colors.transparent,
          destinations: const [
            NavigationDestination(icon: _NavThumb('home'), selectedIcon: _NavThumb('home', selected: true), label: 'Home'),
            NavigationDestination(icon: _NavThumb('library'), selectedIcon: _NavThumb('library', selected: true), label: 'Library'),
            NavigationDestination(icon: _NavThumb('videos'), selectedIcon: _NavThumb('videos', selected: true), label: 'Videos'),
            NavigationDestination(icon: _NavThumb('family'), selectedIcon: _NavThumb('family', selected: true), label: 'Family'),
            NavigationDestination(icon: _NavThumb('search'), selectedIcon: _NavThumb('search', selected: true), label: 'Search'),
            NavigationDestination(icon: _NavThumb('settings'), selectedIcon: _NavThumb('settings', selected: true), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

/// Picture button for a bottom-bar tab. The selected tab gets a bright ring; the others are dimmed.
class _NavThumb extends StatelessWidget {
  const _NavThumb(this.name, {this.selected = false});
  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.outline, width: selected ? 2.5 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Opacity(opacity: selected ? 1 : 0.6, child: Image.asset('assets/home/nav_$name.jpg', fit: BoxFit.cover, gaplessPlayback: true)),
      ),
    );
  }
}

// ---------------------------------------------------------------- Library (Stage A)

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = DownloadEngine.instance;
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([engine, settings, engine.lowDisk]),
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        // Every Library size is drawn in design pixels (rows are 796px wide) and scaled to fit the screen.
        final s = (box.maxWidth - 2 * _libraryPad) / _libraryDesignWidth;
        return ListView(
        padding: const EdgeInsets.all(_libraryPad),
        children: [
          if (engine.lowDisk.value)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sd_storage_outlined, color: AppTheme.danger),
                title: const Text('Storage almost full: downloads paused'),
                subtitle: const Text('Free space or switch to an SD card in Settings, then resume.'),
                trailing: TextButton(onPressed: engine.resumeAfterLowDisk, child: const Text('Resume')),
              ),
            ),
          _LibraryShortcut(art: 'maps', label: 'Offline Maps', page: const MapsScreen(), scale: s, height: 67, artWidth: 192),
          SizedBox(height: 10 * s),
          _LibraryShortcut(art: 'documents', label: 'My Documents: add your own PDFs', page: const MyDocumentsScreen(), scale: s, height: 67, artWidth: 192),
          SizedBox(height: 10 * s),
          _LibraryShortcut(art: 'plants', label: 'Wild Medicinal Plants', page: const WildPlantsScreen(), scale: s, height: 67, artWidth: 192),
          SizedBox(height: 10 * s),
          // Field Guide and Gear live here now that Home follows the new tile layout.
          Row(children: [
            Expanded(child: _LibraryShortcut(art: 'fieldguide', label: 'Field Guide', page: const FieldGuideScreen(), scale: s, height: 72, artWidth: 182, fontSize: 27)),
            SizedBox(width: 22 * s),
            Expanded(child: _LibraryShortcut(art: 'gear', label: 'Gear', page: const GearScreen(), scale: s, height: 72, artWidth: 182, fontSize: 27)),
          ]),
          SizedBox(height: 12 * s),
          if (!settings.sealed)
            FilledButton.icon(
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(settings.enabledCategories.isEmpty ? 'Switch on a category below to sync it' : 'Sync selected categories'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: settings.enabledCategories.isEmpty ? null : () => engine.enqueueCategories(settings.enabledCategories),
            ),
          SizedBox(height: 12 * s),
          for (final c in Services.catalog.categories) _CategoryTile(category: c, scale: s),
        ],
        );
      }),
    );
  }
}

// Library art strips live in assets/library/: shortcut_NAME.png and cat_CATEGORYID.png.
// The art is a fixed width and stretches to whatever height its row ends up at.
class _LibraryArt extends StatelessWidget {
  const _LibraryArt(this.file, {required this.width});
  final String file;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Image.asset('assets/library/$file.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      );
}

// Library geometry, in design pixels: rows are 796px wide in the artwork and scale to the screen.
const double _libraryDesignWidth = 796;
const double _libraryPad = 13;
// Rows are a little taller than the artwork so every title and count stays fully visible.
const double _libraryRowStretch = 1.15;
const _rowGradient = LinearGradient(colors: [AppTheme.card, Color(0xFF0D2B21)]);

// Height of each category row in the design, taken from the supplied strips.
const _categoryRowHeights = {
  'water': 84, 'mechanical': 83, 'medical': 80, 'food': 81, 'carpentry': 69, 'energy': 66, 'transport': 65,
  'comms': 65, 'metallurgy': 65, 'kiwix': 68, 'maps': 66, 'longterm': 73, 'plants': 84, 'models': 93,
};

BoxDecoration _libraryRowDecoration(double scale) => BoxDecoration(
      gradient: _rowGradient,
      borderRadius: BorderRadius.circular(14 * scale),
      border: Border.all(color: AppTheme.outline),
    );

class _LibraryShortcut extends StatelessWidget {
  const _LibraryShortcut({
    required this.art,
    required this.label,
    required this.page,
    required this.scale,
    required this.height,
    required this.artWidth,
    this.fontSize = 29,
  });
  final String art;
  final String label;
  final Widget page;
  final double scale;
  final double height;
  final double artWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        decoration: _libraryRowDecoration(scale),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
            // The design height is a minimum: the row grows if the text needs more room.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height * scale * _libraryRowStretch),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _LibraryArt('shortcut_$art', width: artWidth * scale),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 7 * scale),
                        child: Text(label, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize * scale, height: 1.1, color: Colors.white)),
                      ),
                    ),
                  ),
                  Center(child: Icon(Icons.chevron_right, color: AppTheme.muted, size: 34 * scale)),
                  SizedBox(width: 10 * scale),
                ]),
              ),
            ),
          ),
        ),
      );
}

// A slim art row (art, number, title, ready count, switch) that expands to list its items.
// Built by hand because ExpansionTile enforces a minimum height far taller than the design.
class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.category, required this.scale});
  final Category category;
  final double scale;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final k = widget.scale;
    final s = AppSettings.instance;
    final enabled = s.enabledCategories.contains(category.id);
    final jobs = DownloadEngine.instance.jobs;
    final usable = category.items.where((i) => jobs[i.id]?.isUsable ?? false).length;
    final height = (_categoryRowHeights[category.id] ?? 70) * k;
    return Container(
      margin: EdgeInsets.only(bottom: 6 * k),
      decoration: _libraryRowDecoration(k),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            // The design height is a minimum: the row grows if the text needs more room.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height * _libraryRowStretch),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _LibraryArt('cat_${category.id}', width: 232 * k),
                  Center(child: Container(width: 1, height: height * 0.8, color: AppTheme.warn.withValues(alpha: 0.4))),
                  SizedBox(
                    width: 102 * k,
                    child: Center(child: Text(category.code, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26 * k))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 7 * k),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(category.title, maxLines: 2, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 25 * k, height: 1.1)),
                        Text('$usable / ${category.items.length} ready', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 22 * k, height: 1.1)),
                      ]),
                    ),
                  ),
                  // The standard switch is 52x32pt; fit it into the design's smaller toggle slot.
                  Center(
                    child: SizedBox(
                      width: 90 * k,
                      height: 50 * k,
                      child: FittedBox(
                        child: Switch(
                          value: enabled,
                          onChanged: s.sealed
                              ? null
                              : (v) => s.update((x) => v ? x.enabledCategories.add(category.id) : x.enabledCategories.remove(category.id)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 32 * k),
                ]),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _open
              ? Column(children: [for (final i in category.items) _ItemRow(item: i)])
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final j = DownloadEngine.instance.jobs[item.id];
    final st = j?.status ?? JobStatus.idle;
    final label = switch (st) {
      JobStatus.downloading => 'Downloading ${(j!.progress * 100).toStringAsFixed(0)}%',
      JobStatus.verified => 'Verified (SHA-256 match)',
      JobStatus.unverified => 'Ready · hash recorded, not pinned',
      JobStatus.corrupt => 'Corrupt: checksum mismatch',
      JobStatus.waitingForNetwork => 'Waiting for network',
      JobStatus.insufficientSpace => j?.error ?? 'Not enough space',
      JobStatus.failed => 'Failed: ${j?.error ?? ''}',
      _ => item.isPlaceholder ? 'Set a URL in the catalog' : st.name,
    };
    final color = switch (st) {
      JobStatus.verified || JobStatus.unverified => AppTheme.ok,
      JobStatus.corrupt || JobStatus.failed || JobStatus.insufficientSpace => AppTheme.danger,
      _ => AppTheme.muted,
    };
    return ListTile(
      dense: true,
      title: Text(item.title),
      subtitle: Text(label, style: TextStyle(color: color)),
      trailing: (j?.isUsable ?? false) && item.kind != CategoryKind.model ? const Icon(Icons.chevron_right) : null,
      onTap: (j?.isUsable ?? false) ? () => _open(context, item) : null,
    );
  }

  void _open(BuildContext context, CatalogItem item) {
    final Widget screen = switch (item.kind) {
      CategoryKind.pdf => PdfReaderScreen(item: item),
      CategoryKind.zim => ZimScreen(item: item),
      CategoryKind.map => OfflineMapScreen(item: item),
      CategoryKind.model => const SizedBox.shrink(),
    };
    if (item.kind == CategoryKind.model) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AirGapGate(featureName: item.title, child: screen)));
  }
}

// ---------------------------------------------------------------- Search (FTS5)

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  SearchResult? _r;

  void _run() => setState(() => _r = Services.fts.search(_q.text));

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(),
          decoration: const InputDecoration(
            labelText: 'Search manuals',
            hintText: 'water AND (boil OR bleach)   "pressure canner"   tourniquet -combat   weld*',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      if (r != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(r.error ?? '${r.hits.length} results · ${r.elapsed.inMicroseconds / 1000} ms',
              style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: r?.hits.length ?? 0,
          itemBuilder: (context, i) {
            final h = r!.hits[i];
            return ListTile(
              title: Text('${h.title} · p. ${h.page}'),
              subtitle: _Snippet(h.snippet),
              onTap: () {
                final item = Services.catalog.itemById(h.itemId);
                if (item == null) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(item: item, page: h.page)));
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _Snippet extends StatelessWidget {
  const _Snippet(this.raw);
  final String raw;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final parts = raw.split('\u0002');
    spans.add(TextSpan(text: parts.first));
    for (final p in parts.skip(1)) {
      final end = p.indexOf('\u0003');
      if (end < 0) {
        spans.add(TextSpan(text: p));
        continue;
      }
      spans.add(TextSpan(text: p.substring(0, end), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)));
      spans.add(TextSpan(text: p.substring(end + 1)));
    }
    return Text.rich(TextSpan(style: const TextStyle(color: AppTheme.muted), children: spans), maxLines: 4, overflow: TextOverflow.ellipsis);
  }
}

// ---------------------------------------------------------------- Settings

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => ListView(children: [
        ListTile(
          leading: const Icon(Icons.explore_outlined, color: AppTheme.accent),
          title: const Text('How to use Blackout IQ', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('A quick picture tour of every part of the app'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TourScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline, color: AppTheme.accent),
          title: const Text('About, safety and credits', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Emergency and medical notice, privacy, sources, licences'),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Low-power mode'),
          subtitle: const Text('Fewer AI threads, shorter answers, no background embedding, no map GPS dot'),
          value: s.lowPowerMode,
          onChanged: (v) async {
            await s.update((x) => x.lowPowerMode = v);
            await Services.refreshTier();
          },
        ),
        SwitchListTile(
          title: const Text('Background AI indexing'),
          subtitle: const Text('Embed new documents for AI questions while the app is open'),
          value: s.backgroundEmbedding,
          onChanged: (v) async {
            await s.update((x) => x.backgroundEmbedding = v);
            if (v) Services.scheduler?.run();
          },
        ),
        SwitchListTile(
          title: const Text('Verify files before opening'),
          subtitle: const Text('Re-check SHA-256 each time a manual is opened'),
          value: s.verifyOnOpen,
          onChanged: (v) => s.update((x) => x.verifyOnOpen = v),
        ),
        const Divider(),
        ListTile(
          leading: Icon(s.sealed ? Icons.lock : Icons.lock_open, color: s.sealed ? AppTheme.ok : AppTheme.accent),
          title: Text(s.sealed ? 'Node sealed (Stage B)' : 'Seal node (enter Stage B)'),
          subtitle: Text(s.sealed
              ? 'All non-loopback connections are blocked inside the app. ${NetworkLockdown.blockedLog.length} blocked attempts logged.'
              : 'Blocks every outbound connection from the app. Turn on Airplane Mode as well.'),
          onTap: () => _toggleSeal(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.radar),
          title: const Text('Air-gap check'),
          subtitle: ValueListenableBuilder<AirGapStatus>(
            valueListenable: AirGapMonitor.instance,
            builder: (_, st, __) => Text(st.activeInterfaces.isEmpty ? st.level.name : st.activeInterfaces.join(', ')),
          ),
          onTap: AirGapMonitor.instance.refresh,
        ),
        ListTile(
          leading: const Icon(Icons.analytics_outlined),
          title: const Text('Index'),
          subtitle: Text(Services.fts.stats().entries.map((e) => '${e.key}: ${e.value}').join(' · ')),
        ),
      ]),
    );
  }

  Future<void> _toggleSeal(BuildContext context, AppSettings s) async {
    if (!s.sealed) {
      final jobs = DownloadEngine.instance.jobs.values;
      final busy = jobs.any((j) => j.status == JobStatus.downloading || j.status == JobStatus.verifying);
      if (busy) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for downloads and verification to finish first.')));
        return;
      }
      NetworkLockdown.engage();
      await s.update((x) => x.sealed = true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unseal the node?'),
        content: const Text('The app will be able to reach the internet again. Only do this to sync new material.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unseal')),
        ],
      ),
    );
    if (ok == true) {
      NetworkLockdown.release();
      await s.update((x) => x.sealed = false);
    }
  }
}
