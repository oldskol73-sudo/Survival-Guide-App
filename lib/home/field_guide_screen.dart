// Field Guide: topic tiles that jump straight into the offline library, filtered by subject.
// Each tile runs a full-text search over the indexed manuals; tapping a hit opens the PDF at that page.

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/theme.dart';
import '../viewers/viewer_screens.dart';

class GuideTopic {
  const GuideTopic(this.title, this.icon, this.query, {this.category});
  final String title;
  final IconData icon;
  final String query;
  final String? category; // catalog category id, or null for the whole library
}

const _guideTopics = <GuideTopic>[
  GuideTopic('Fire', Icons.local_fire_department_outlined, 'fire tinder kindling ignite'),
  GuideTopic('Shelter', Icons.cabin_outlined, 'shelter construction insulation', category: 'carpentry'),
  GuideTopic('Water', Icons.water_drop_outlined, 'water purification disinfection', category: 'water'),
  GuideTopic('Food', Icons.restaurant_outlined, 'food preservation foraging', category: 'food'),
  GuideTopic('Medical', Icons.medical_services_outlined, 'first aid treatment wound', category: 'medical'),
  GuideTopic('Navigation', Icons.explore_outlined, 'navigation compass map direction'),
  GuideTopic('Signaling', Icons.cell_tower, 'signal radio emergency communication', category: 'comms'),
  GuideTopic('Weather', Icons.cloud_outlined, 'weather storm cold heat'),
  GuideTopic('Vehicle', Icons.directions_car_outlined, 'vehicle repair engine', category: 'transport'),
  GuideTopic('Power', Icons.solar_power_outlined, 'solar power battery generator', category: 'energy'),
  GuideTopic('Tools & metal', Icons.hardware_outlined, 'tools forge weld metal', category: 'metallurgy'),
  GuideTopic('Long term', Icons.calendar_month_outlined, 'long term self sufficiency', category: 'longterm'),
];

class FieldGuideScreen extends StatelessWidget {
  const FieldGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Guide')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          for (final t in _guideTopics)
            Material(
              color: AppTheme.card,
              shape: RoundedRectangleBorder(side: const BorderSide(color: AppTheme.outline), borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TopicResultsScreen(topic: t))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Icon(t.icon, color: AppTheme.accent, size: 28),
                    Text(t.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TopicResultsScreen extends StatelessWidget {
  const TopicResultsScreen({super.key, required this.topic});
  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final r = Services.fts.search(topic.query, category: topic.category, limit: 40);
    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: r.hits.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  r.error ?? 'Nothing indexed for ${topic.title} yet. Add manuals in the Library tab and let indexing finish.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: r.hits.length,
              itemBuilder: (context, i) {
                final h = r.hits[i];
                final snippet = h.snippet.replaceAll('\u0002', '').replaceAll('\u0003', '');
                return Card(
                  child: ListTile(
                    title: Text('${h.title} · p. ${h.page}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      final item = Services.catalog.itemById(h.itemId);
                      if (item == null) return;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(item: item, page: h.page)));
                    },
                  ),
                );
              },
            ),
    );
  }
}
