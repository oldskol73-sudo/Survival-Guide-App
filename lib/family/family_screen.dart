// Family tab: who your people are, who to call, and where to meet. Stored only on this device.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../vault/vault_screen.dart';
import 'emergency_numbers.dart';
import 'family_store.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FamilyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Family', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Text('Emergency contacts & gathering points', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 16),
          _SummaryCard(store: store),
          const SizedBox(height: 16),
          const _VaultTile(),
          const SizedBox(height: 16),
          _LocalEmergencyCard(store: store),
          const SizedBox(height: 24),
          _Section(
            store: store,
            kind: EntryKind.member,
            title: 'Family Members',
            emptyText: 'Add your first family member',
            icon: Icons.groups_outlined,
            noteLabel: 'Medical notes, allergies, meds',
          ),
          const SizedBox(height: 24),
          _Section(
            store: store,
            kind: EntryKind.contact,
            title: 'Emergency Contacts',
            emptyText: 'Add a doctor, neighbor or out-of-town contact',
            icon: Icons.call_outlined,
            noteLabel: 'Role or notes',
          ),
          const SizedBox(height: 24),
          _Section(
            store: store,
            kind: EntryKind.place,
            title: 'Gathering Points',
            emptyText: 'Add a place to meet if you are separated',
            icon: Icons.place_outlined,
            noteLabel: 'Address or directions',
            showPhone: false,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.store});
  final FamilyStore store;

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String label, int n) => Expanded(
          child: Column(children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
            Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, border: Border.all(color: AppTheme.outline), borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
          stat(Icons.groups_outlined, 'Members', store.members.length),
          stat(Icons.call_outlined, 'Contacts', store.contacts.length),
          stat(Icons.place_outlined, 'Locations', store.places.length),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _share(context, store),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('SHARE', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _import(context, store),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppTheme.accent, side: const BorderSide(color: AppTheme.accent)),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('IMPORT', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _share(BuildContext context, FamilyStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final empty = store.members.isEmpty && store.contacts.isEmpty && store.places.isEmpty;
    if (empty) {
      messenger.showSnackBar(const SnackBar(content: Text('Add a member, contact or place first.')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: store.exportCode()));
    messenger.showSnackBar(const SnackBar(content: Text('Family code copied. Paste it into a message to a family member, who taps Import.')));
  }

  Future<void> _import(BuildContext context, FamilyStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = TextEditingController();
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (clip.trim().startsWith('SNFAMILY1:')) c.text = clip.trim();
    if (!context.mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import family code'),
        content: TextField(controller: c, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'Paste the code you received')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Import')),
        ],
      ),
    );
    if (code == null) return;
    final added = await store.importCode(code);
    messenger.showSnackBar(SnackBar(content: Text(added == null ? 'That is not a valid family code.' : 'Added $added new ${added == 1 ? 'entry' : 'entries'}.')));
  }
}

class _LocalEmergencyCard extends StatelessWidget {
  const _LocalEmergencyCard({required this.store});
  final FamilyStore store;

  @override
  Widget build(BuildContext context) {
    final detected = PlatformDispatcher.instance.locale.countryCode;
    final code = store.countryOverride ?? detected;
    final info = emergencyFor(code);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.sos.withValues(alpha: 0.14), border: Border.all(color: AppTheme.danger), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _pickCountry(context, store),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.phone_in_talk, color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Local Emergency · ${flagFor(code)} ${info.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              const Icon(Icons.expand_more, color: AppTheme.muted),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, number) in info.numbers)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: AppTheme.danger), borderRadius: BorderRadius.circular(20)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$label  '),
                TextSpan(text: number, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800, fontSize: 16)),
              ])),
            ),
        ]),
        if (!emergencyByCountry.containsKey(code?.toUpperCase()))
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Region not in the built-in list. 112 works on mobile networks in most countries. Tap the title to pick another.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ),
      ]),
    );
  }

  Future<void> _pickCountry(BuildContext context, FamilyStore store) async {
    final entries = emergencyByCountry.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name));
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: const Text('Follow my phone\'s region'), leading: const Icon(Icons.my_location), onTap: () => Navigator.pop(ctx, '')),
          for (final e in entries) ListTile(leading: Text(flagFor(e.key), style: const TextStyle(fontSize: 22)), title: Text(e.value.name), onTap: () => Navigator.pop(ctx, e.key)),
        ]),
      ),
    );
    if (picked != null) await store.setCountry(picked.isEmpty ? null : picked);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.store, required this.kind, required this.title, required this.emptyText, required this.icon, required this.noteLabel, this.showPhone = true});
  final FamilyStore store;
  final EntryKind kind;
  final String title;
  final String emptyText;
  final IconData icon;
  final String noteLabel;
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    final items = store.list(kind);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        IconButton.filled(tooltip: 'Add', onPressed: () => _edit(context, null), icon: const Icon(Icons.add)),
      ]),
      const SizedBox(height: 8),
      if (items.isEmpty)
        InkWell(
          onTap: () => _edit(context, null),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.card, border: Border.all(color: AppTheme.outline), borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 36, color: AppTheme.muted),
              const SizedBox(height: 8),
              Text(emptyText, style: const TextStyle(color: AppTheme.muted)),
            ]),
          ),
        )
      else
        for (final e in items)
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppTheme.accentSoft, foregroundColor: AppTheme.accent, child: Icon(icon, size: 20)),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: (e.phone.isEmpty && e.note.isEmpty) ? null : Text([if (e.phone.isNotEmpty) e.phone, if (e.note.isNotEmpty) e.note].join('\n')),
              isThreeLine: e.phone.isNotEmpty && e.note.isNotEmpty,
              trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(context, e)),
              onTap: () => _edit(context, e),
            ),
          ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, FamilyEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${e.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await store.remove(kind, e);
  }

  Future<void> _edit(BuildContext context, FamilyEntry? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add to $title' : 'Edit'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            if (showPhone) ...[
              const SizedBox(height: 12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            ],
            const SizedBox(height: 12),
            TextField(controller: note, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: noteLabel)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final n = name.text.trim();
    final entry = FamilyEntry(id: existing?.id ?? FamilyStore.newId(), name: n, phone: phone.text.trim(), note: note.text.trim());
    if (saved == true && n.isNotEmpty) await store.upsert(kind, entry);
  }
}

/// Entry to the encrypted documents vault (IDs, insurance, medical records).
class _VaultTile extends StatelessWidget {
  const _VaultTile();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(side: const BorderSide(color: AppTheme.outline), borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppTheme.accentSoft, shape: BoxShape.circle, border: Border.all(color: AppTheme.outline)),
              child: const Icon(Icons.lock_rounded, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Locked Vault · IDs, insurance, medical', style: TextStyle(color: AppTheme.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ]),
        ),
      ),
    );
  }
}
