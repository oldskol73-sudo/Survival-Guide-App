import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'checklist_store.dart';

class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key, this.kitId = 'survival'});
  final String kitId;

  @override
  Widget build(BuildContext context) {
    final store = ChecklistStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final kit = store.kit(kitId);
        final total = store.totalFor(kitId);
        final done = store.doneFor(kitId);
        return Scaffold(
          appBar: AppBar(
            title: Text(kitId == 'survival' ? 'Survival Kit Checklist' : kit.title),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'reset' && await _confirm(context)) store.resetTicks(kitId);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Untick all'))],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addItem(context, store, kitId),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Text('$done of $total packed', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 10, borderRadius: BorderRadius.circular(5), backgroundColor: AppTheme.accentSoft),
              for (final g in store.groupsFor(kitId)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Text(g, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                ),
                Card(
                  child: Column(children: [
                    for (final item in store.itemsFor(kitId).where((i) => i.group == g))
                      CheckboxListTile(
                        value: item.done,
                        onChanged: (_) => store.toggle(item),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(item.title, style: TextStyle(decoration: item.done ? TextDecoration.lineThrough : null, color: item.done ? AppTheme.muted : AppTheme.text)),
                        subtitle: item.note == null ? null : Text(item.note!),
                        secondary: item.custom ? IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => store.remove(item)) : null,
                      ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _addItem(BuildContext context, ChecklistStore store, String kitId) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add an item'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Add')),
        ],
      ),
    );
    if (text != null) await store.add(kitId, text);
  }

  Future<bool> _confirm(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Untick everything?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Untick all')),
          ],
        ),
      ) ??
      false;
}
