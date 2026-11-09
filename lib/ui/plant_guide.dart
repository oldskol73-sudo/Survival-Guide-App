// Wild Medicinal Plants picture guide: 25 flowering plants shown as photos, five to a row, each opening a
// page with its traditional uses and cautions. Content and photo credits live in assets/plants/plants.json.
// Everything is bundled, so it works offline. Entries record traditional use only; they are not medical advice.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// How risky a plant is, shown as a badge on its tile.
enum PlantLevel { standard, caution, danger }

class PlantEntry {
  const PlantEntry({
    required this.id,
    required this.name,
    required this.latin,
    required this.family,
    required this.level,
    required this.align,
    required this.parts,
    required this.uses,
    required this.cautions,
    required this.lookalikes,
    required this.image,
    required this.creditAuthor,
    required this.creditLicense,
    required this.creditFile,
  });

  final String id;
  final String name;
  final String latin;
  final String family;
  final PlantLevel level;
  final Alignment align; // which part of the photo stays in view when it is cropped to a square
  final String parts;
  final List<String> uses;
  final String cautions;
  final String lookalikes;
  final String image;
  final String creditAuthor;
  final String creditLicense;
  final String creditFile;

  factory PlantEntry.fromJson(Map<String, dynamic> j) {
    final align = (j['align'] as List).cast<num>();
    final credit = j['credit'] as Map<String, dynamic>;
    return PlantEntry(
      id: j['id'] as String,
      name: j['name'] as String,
      latin: j['latin'] as String,
      family: j['family'] as String,
      level: PlantLevel.values.byName(j['level'] as String),
      align: Alignment(align[0].toDouble(), align[1].toDouble()),
      parts: j['parts'] as String,
      uses: (j['uses'] as List).cast<String>(),
      cautions: j['cautions'] as String,
      lookalikes: j['lookalikes'] as String,
      image: j['image'] as String,
      creditAuthor: credit['author'] as String,
      creditLicense: credit['license'] as String,
      creditFile: credit['file'] as String,
    );
  }

  static Future<List<PlantEntry>>? _cache;

  /// Loads the bundled list once and reuses it.
  static Future<List<PlantEntry>> load() => _cache ??= rootBundle
      .loadString('assets/plants/plants.json')
      .then((s) => [for (final j in (jsonDecode(s) as List).cast<Map<String, dynamic>>()) PlantEntry.fromJson(j)]);
}

Color _levelColor(PlantLevel l) => switch (l) {
      PlantLevel.danger => AppTheme.danger,
      PlantLevel.caution => AppTheme.warn,
      PlantLevel.standard => AppTheme.muted,
    };

/// The picture grid: five photos per row with the plant name under each.
class PlantGrid extends StatelessWidget {
  const PlantGrid({super.key, required this.plants});
  final List<PlantEntry> plants;

  static const _columns = 5;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final tile = (box.maxWidth - _gap * (_columns - 1)) / _columns;
        // Cap text scaling so two-line names always fit under their photo.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _gap,
              mainAxisSpacing: 10,
              mainAxisExtent: tile + 36,
            ),
            itemBuilder: (context, i) => _PlantTile(plant: plants[i]),
          ),
        );
      });
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.plant});
  final PlantEntry plant;

  @override
  Widget build(BuildContext context) {
    final flagged = plant.level != PlantLevel.standard;
    return Semantics(
      button: true,
      label: '${plant.name}, ${plant.latin}${flagged ? ', caution' : ''}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: flagged ? _levelColor(plant.level) : AppTheme.outline, width: flagged ? 1.5 : 1),
                  ),
                  child: Image.asset(plant.image, fit: BoxFit.cover, alignment: plant.align, cacheWidth: 300, filterQuality: FilterQuality.medium),
                ),
              ),
              if (flagged)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(Icons.warning_amber_rounded, size: 13, color: _levelColor(plant.level)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(
            plant.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({super.key, required this.plant});
  final PlantEntry plant;

  @override
  Widget build(BuildContext context) {
    final danger = plant.level == PlantLevel.danger;
    return Scaffold(
      appBar: AppBar(title: Text(plant.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: Image.asset(plant.image, fit: BoxFit.cover, alignment: plant.align, filterQuality: FilterQuality.medium),
            ),
          ),
          const SizedBox(height: 12),
          Text(plant.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(plant.latin, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: AppTheme.muted)),
          Text(plant.family, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          if (danger)
            _Notice(
              color: AppTheme.danger,
              icon: Icons.dangerous_outlined,
              title: 'Poisonous: do not eat or brew',
              body: plant.cautions,
            ),
          _Section(icon: Icons.local_florist_outlined, title: danger ? 'What it is known for' : 'Part used', body: danger ? null : plant.parts),
          _Section(
            icon: Icons.menu_book_outlined,
            title: danger ? 'Why it matters' : 'Traditional use',
            bullets: plant.uses,
          ),
          if (!danger)
            _Notice(
              color: plant.level == PlantLevel.caution ? AppTheme.warn : AppTheme.muted,
              icon: Icons.warning_amber_rounded,
              title: 'Cautions',
              body: plant.cautions,
            ),
          _Notice(color: AppTheme.warn, icon: Icons.visibility_outlined, title: 'Look-alikes', body: plant.lookalikes),
          const SizedBox(height: 4),
          const Text(
            'This is a record of traditional and historical use, not medical advice and not a guide to what is safe or effective. '
            'Never eat, brew or apply a wild plant unless an expert has identified it in person.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          // The photos are Creative Commons licensed; this credit is required by those licences.
          Text(
            'Photo: ${plant.creditAuthor}, ${plant.creditLicense}, via ${'Wikimedia Commons'} (${plant.creditFile}). Resized and cropped.',
            style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, this.body, this.bullets});
  final IconData icon;
  final String title;
  final String? body;
  final List<String>? bullets;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          if (body != null) Text(body!, style: const TextStyle(height: 1.4)),
          for (final b in bullets ?? const <String>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(height: 1.4)),
                Expanded(child: Text(b, style: const TextStyle(height: 1.4))),
              ]),
            ),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.icon, required this.title, required this.body});
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color))),
          ]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.4)),
        ]),
      );
}
