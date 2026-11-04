// Gear: the list of kits, each with live packing progress. Tapping a kit opens its checklist.

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'checklist_screen.dart';
import 'checklist_store.dart';

class GearScreen extends StatelessWidget {
  const GearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ChecklistStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Gear')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Kits stay on this device. Tick items off as you pack them.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 12),
            for (final k in kits)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(k.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.subtitle),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: store.totalFor(k.id) == 0 ? 0 : store.doneFor(k.id) / store.totalFor(k.id),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: AppTheme.accentSoft,
                      ),
                      const SizedBox(height: 4),
                      Text('${store.doneFor(k.id)} of ${store.totalFor(k.id)} packed', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChecklistScreen(kitId: k.id))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
