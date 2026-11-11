// Wild Medicinal Plants: public-domain botanical references the user can download one at a time.
// Every title is a US Government publication or a pre-1926 book, so it can be stored offline and redistributed.
// The screen leads with a safety notice because plant identification from a book is not a safe basis for eating
// or medicating anything.

import 'package:flutter/material.dart';

import '../airgap/airgap_banner.dart';
import '../catalog/catalog_models.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../downloads/download_engine.dart';
import '../viewers/viewer_screens.dart';
import 'plant_guide.dart';
import 'source_link.dart';

const _what = <String, String>{
  'millspaugh-medicinal-plants-v1-1892': 'Colour plates of 180 plants with description, range, history, uses and poisoning effects.',
  'millspaugh-medicinal-plants-v2-1892': 'Second half of the colour-plate set: description, range, history, uses and poisoning effects.',
  'henkel-wild-medicinal-1906': 'Name index: common and scientific names, family, habit, range and parts used. No pictures.',
  'henkel-weeds-medicine-1904': 'Drawings and notes on common weeds with a medicinal history, with how each was gathered and used.',
  'chesnut-poisonous-1898': 'Thirty dangerous plants with drawings, where they grow, which parts poison, and the effects.',
  'marsh-stock-poisoning-1924': 'Illustrated guide to poisonous range plants, how to tell them apart and what poisoning looks like.',
  'densmore-chippewa-plants-1928': 'Documented traditional Ojibwe uses of plants for food, medicine and tools, with plates.',
};

class WildPlantsScreen extends StatelessWidget {
  const WildPlantsScreen({super.key});

  Category? get _category {
    for (final c in Services.catalog.categories) {
      if (c.id == 'plants') return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final engine = DownloadEngine.instance;
    final settings = AppSettings.instance;
    final cat = _category;
    return Scaffold(
      appBar: AppBar(title: const Text('Wild Medicinal Plants')),
      body: ListenableBuilder(
        listenable: Listenable.merge([engine, settings]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // The short rule stays visible; the full notice expands underneath it.
            Card(
              color: AppTheme.card,
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(side: const BorderSide(color: AppTheme.danger), borderRadius: BorderRadius.circular(16)),
              child: const ExpansionTile(
                shape: Border(),
                collapsedShape: Border(),
                tilePadding: EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                leading: Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                title: Text('Read before you pick or eat anything', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Text('Never use a wild plant unless an expert has identified it in person. Tap for the full notice.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.3)),
                children: [
                  Text(
                    'Never eat, brew or apply a wild plant unless an expert has identified it in person. Many deadly plants look like harmless ones: '
                    'poison hemlock resembles wild carrot, water hemlock resembles wild parsnip, and death camas resembles wild onion. '
                    'One wrong guess can kill.\n\n'
                    'These entries and books are historical. They record what people once used, not what is safe or effective today. Doses, remedies and '
                    'safety statements are out of date, and some plants once used as medicine are now known to be harmful. They are not medical advice. '
                    'In an emergency, call your local emergency number (911 in the US) or Poison Control (1-800-222-1222 in the US).',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Tap a plant to read about it', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            const Text(
              '25 flowering plants, shown with their traditional uses and cautions. A warning mark means take extra care.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.3),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<PlantEntry>>(
              future: PlantEntry.load(),
              builder: (context, snap) {
                if (snap.hasError) return const Text('The plant guide could not be loaded.', style: TextStyle(color: AppTheme.danger));
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                return PlantGrid(plants: snap.data!);
              },
            ),
            const SizedBox(height: 16),
            // The downloadable books are tucked away so the pictures get the screen.
            Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.menu_book_outlined, color: AppTheme.accent),
                title: Text('Reference books (${cat?.items.length ?? 0})', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                  'Public-domain books you can download for offline reading. Start with the poisonous-plant guides.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12.5, height: 1.3),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                children: [
                  if (cat == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('This section is not in the catalog.', style: TextStyle(color: AppTheme.muted)),
                    )
                  else
                    for (final i in cat.items) _PlantBook(item: i, sealed: settings.sealed),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Plant photos are from Wikimedia Commons under Creative Commons licences; each photo\'s author and licence are shown on its plant page.',
              style: TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantBook extends StatelessWidget {
  const _PlantBook({required this.item, required this.sealed});
  final CatalogItem item;
  final bool sealed;

  @override
  Widget build(BuildContext context) {
    final engine = DownloadEngine.instance;
    final j = engine.jobs[item.id];
    final st = j?.status ?? JobStatus.idle;
    final usable = j?.isUsable ?? false;
    final busy = st == JobStatus.downloading || st == JobStatus.queued || st == JobStatus.waitingForNetwork;
    final mb = item.sizeBytes == null ? null : item.sizeBytes! / 1048576;
    final status = switch (st) {
      JobStatus.downloading => 'Downloading ${((j?.progress ?? 0) * 100).toStringAsFixed(0)}%',
      JobStatus.queued => 'Queued',
      JobStatus.waitingForNetwork => 'Waiting for network',
      JobStatus.insufficientSpace => j?.error ?? 'Not enough space',
      JobStatus.failed => 'Failed: ${j?.error ?? ''}',
      JobStatus.corrupt => 'Corrupt: checksum mismatch',
      _ => usable ? 'On this phone' : (mb == null ? 'Not downloaded' : 'Not downloaded · ${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB'),
    };
    final statusColor = usable
        ? AppTheme.ok
        : (st == JobStatus.failed || st == JobStatus.corrupt || st == JobStatus.insufficientSpace)
            ? AppTheme.danger
            : AppTheme.muted;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_what[item.id] ?? '', style: const TextStyle(color: AppTheme.muted, height: 1.35)),
          const SizedBox(height: 4),
          Text('Licence: ${item.license}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          if (item.sourceUrl != null) SourceLink(url: item.sourceUrl!),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(status, style: TextStyle(color: statusColor))),
            if (usable)
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AirGapGate(featureName: item.title, child: PdfReaderScreen(item: item)))),
                child: const Text('Open'),
              )
            else if (busy)
              OutlinedButton(onPressed: () => engine.cancel(item.id), child: const Text('Cancel'))
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Download'),
                onPressed: sealed
                    ? null
                    : () async {
                        final r = await engine.enqueue(item);
                        if (!context.mounted) return;
                        if (r == EnqueueResult.rejected || r == EnqueueResult.placeholder) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start this download')));
                        }
                      },
              ),
          ]),
        ]),
      ),
    );
  }
}
