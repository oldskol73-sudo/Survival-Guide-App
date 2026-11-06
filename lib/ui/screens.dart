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
      bottomNavigationBar: NavigationBar(
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
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
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
          _LibraryShortcut(icon: Icons.map_rounded, label: 'Offline Maps', page: const MapsScreen()),
          const SizedBox(height: 10),
          _LibraryShortcut(icon: Icons.note_add_rounded, label: 'My Documents: add your own PDFs', page: const MyDocumentsScreen()),
          const SizedBox(height: 10),
          // Field Guide and Gear live here now that Home follows the new tile layout.
          Row(children: [
            Expanded(child: _LibraryShortcut(icon: Icons.menu_book_rounded, label: 'Field Guide', page: const FieldGuideScreen())),
            const SizedBox(width: 10),
            Expanded(child: _LibraryShortcut(icon: Icons.backpack_rounded, label: 'Gear', page: const GearScreen())),
          ]),
          const SizedBox(height: 12),
          if (!settings.sealed)
            FilledButton.icon(
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Sync selected categories'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => engine.enqueueCategories(settings.enabledCategories),
            ),
          const SizedBox(height: 12),
          for (final c in Services.catalog.categories) _CategoryTile(category: c),
        ],
      ),
    );
  }
}

class _LibraryShortcut extends StatelessWidget {
  const _LibraryShortcut({required this.icon, required this.label, required this.page});
  final IconData icon;
  final String label;
  final Widget page;

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.card,
        shape: RoundedRectangleBorder(side: const BorderSide(color: AppTheme.outline), borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Row(children: [
              Icon(icon, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              const Icon(Icons.chevron_right, color: AppTheme.muted),
            ]),
          ),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final enabled = s.enabledCategories.contains(category.id);
    final jobs = DownloadEngine.instance.jobs;
    final usable = category.items.where((i) => jobs[i.id]?.isUsable ?? false).length;
    return Card(
      child: ExpansionTile(
        leading: Text(category.code, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
        title: Text(category.title),
        subtitle: Text('$usable / ${category.items.length} ready', style: const TextStyle(color: AppTheme.muted)),
        trailing: Switch(
          value: enabled,
          onChanged: s.sealed
              ? null
              : (v) => s.update((x) => v ? x.enabledCategories.add(category.id) : x.enabledCategories.remove(category.id)),
        ),
        children: [for (final i in category.items) _ItemRow(item: i)],
      ),
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
