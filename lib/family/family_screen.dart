// Family tab: who your people are, who to call, and where to meet. Stored only on this device.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../vault/vault_screen.dart';
import 'emergency_numbers.dart';
import 'family_share.dart';
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
          // Emergency Contacts: the picture card carries the local 911 / country picker, with your own contacts under it.
          _Section(
            store: store,
            kind: EntryKind.contact,
            title: 'Emergency Contacts',
            top: _LocalEmergencyCard(store: store),
            emptyText: 'Nothing here yet. Tap + to add a doctor, neighbor or out-of-town contact',
            icon: Icons.call_outlined,
            noteLabel: 'Role or notes',
          ),
          const SizedBox(height: 24),
          _Section(
            store: store,
            kind: EntryKind.member,
            title: 'Family Members',
            banner: 'assets/home/family_members.jpg',
            bannerAlignX: -0.92,
            emptyText: 'Nothing here yet. Tap + to add your first family member',
            icon: Icons.groups_outlined,
            noteLabel: 'Medical notes, allergies, meds',
          ),
          const SizedBox(height: 24),
          _Section(
            store: store,
            kind: EntryKind.place,
            title: 'Gathering Points',
            banner: 'assets/home/family_places.jpg',
            bannerAlignX: -0.45,
            emptyText: 'Nothing here yet. Tap + to add a place to meet if you are separated',
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
    const gold = Color(0xFFE3B341);
    Widget stat(IconData icon, String label, int n) => Expanded(
          child: Semantics(
            label: '$label: $n',
            excludeSemantics: true,
            child: Column(children: [
              Icon(icon, color: gold, size: 26),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Color(0xFFEAF2EC), fontSize: 14)),
              Text('$n', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        );
    Widget divider() => Container(width: 1, height: 58, color: gold.withValues(alpha: 0.45));
    return Container(
      foregroundDecoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A24B), width: 1.6), borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          // Forest picture behind the counts and buttons (the numbers and buttons themselves are live widgets).
          Positioned.fill(child: Image.asset('assets/home/family_summary_bg.jpg', fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.medium)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                stat(Icons.groups_rounded, 'Members', store.members.length),
                divider(),
                stat(Icons.phone_in_talk_rounded, 'Contacts', store.contacts.length),
                divider(),
                stat(Icons.place_outlined, 'Locations', store.places.length),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _PillButton(icon: Icons.qr_code_2, label: 'SHARE', sub: 'ENCRYPTED QR', gold: true, onTap: () => shareFamilyCode(context, store))),
                const SizedBox(width: 12),
                Expanded(child: _PillButton(icon: Icons.qr_code_scanner_rounded, label: 'IMPORT', sub: 'SCAN OR PASTE', gold: false, onTap: () => importFamilyCode(context, store))),
              ]),
            ]),
          ),
        ]),
      ),
    );
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
    return Semantics(
      container: true,
      label: 'Emergency Contacts. Local emergency number for ${info.name}.',
      child: Container(
        foregroundDecoration: BoxDecoration(border: Border.all(color: AppTheme.danger.withValues(alpha: 0.65), width: 1.5), borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            // The Emergency Contacts picture fills the card; a dark wash keeps the text readable over it.
            Positioned.fill(child: Image.asset('assets/home/family_contacts.jpg', fit: BoxFit.cover, alignment: Alignment.centerLeft, filterQuality: FilterQuality.medium)),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73061410), Color(0xE0061410)])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('EMERGENCY CONTACTS', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _pickCountry(context, store),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.phone_in_talk, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Local Emergency \u00b7 ${flagFor(code)} ${info.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      const Icon(Icons.expand_more, color: AppTheme.muted),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (label, number) in info.numbers)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0x99061410), border: Border.all(color: AppTheme.danger), borderRadius: BorderRadius.circular(20)),
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
            ),
          ]),
        ),
      ),
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

class _Section extends StatefulWidget {
  const _Section({required this.store, required this.kind, required this.title, this.banner, this.bannerAlignX = -1, this.top, required this.emptyText, required this.icon, required this.noteLabel, this.showPhone = true});
  final FamilyStore store;
  final EntryKind kind;
  final String title;
  final String? banner; // picture tile for the section; tap it to show or hide the list
  final double bannerAlignX; // which part of the wide picture to show: -1 = left edge, 1 = right edge
  final Widget? top; // replaces the picture tile (the Emergency Contacts card)
  final String emptyText;
  final IconData icon;
  final String noteLabel;
  final bool showPhone;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  // The saved entries stay tucked away until the section is tapped, so the Family screen stays short.
  bool _open = false;

  FamilyStore get store => widget.store;
  EntryKind get kind => widget.kind;
  String get title => widget.title;
  IconData get icon => widget.icon;

  static const _anim = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final items = store.list(kind);
    final count = items.length;
    final top = widget.top;
    final banner = widget.banner;
    void toggle() => setState(() => _open = !_open);
    final addButton = IconButton.filled(tooltip: 'Add to $title', onPressed: () => _edit(context, null), icon: const Icon(Icons.add));
    final chevron = AnimatedRotation(turns: _open ? 0.5 : 0, duration: _anim, child: const Icon(Icons.expand_more_rounded, color: AppTheme.muted));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (top != null) ...[
        top,
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'My $title, $count saved',
              hint: _open ? 'Tap to hide' : 'Tap to show',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(children: [
                    Expanded(child: Text(count == 0 ? 'My $title' : 'My $title ($count)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    chevron,
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          addButton,
        ]),
      ] else
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '$title, $count saved',
              hint: _open ? 'Tap to hide' : 'Tap to show',
              excludeSemantics: true,
              child: AspectRatio(
                aspectRatio: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(banner!, fit: BoxFit.cover, alignment: Alignment(widget.bannerAlignX, 0), filterQuality: FilterQuality.medium),
                    // Dark wash at the bottom so the live title reads over the picture.
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00061410), Color(0xF2061410)], stops: [0.6, 1.0])),
                    ),
                    Positioned(
                      left: 16,
                      right: 70,
                      bottom: 14,
                      // One line, shrunk to fit, so the picture above stays clear.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(count == 0 ? title : '$title  ·  $count',
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF1D58A),
                              shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
                            )),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: const Color(0xCC061410), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE3B341), width: 1.6)),
                        child: AnimatedRotation(turns: _open ? 0.5 : 0, duration: _anim, child: const Icon(Icons.expand_more_rounded, color: Color(0xFFE3B341), size: 30)),
                      ),
                    ),
                    DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.outline, width: 1.5))),
                    Material(color: Colors.transparent, child: InkWell(onTap: toggle)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          addButton,
        ]),
      AnimatedSize(
        duration: _anim,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: InkWell(onTap: () => _edit(context, null), child: Text(widget.emptyText, style: const TextStyle(color: AppTheme.muted))),
                      )
                    : Column(children: [
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
                      ]),
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

  /// Short on purpose: a long title wrapped onto three lines and left almost no room for the fields above the keyboard.
  String get _addTitle => switch (kind) {
        EntryKind.contact => 'New contact',
        EntryKind.member => 'New family member',
        EntryKind.place => 'New gathering point',
      };

  Future<void> _edit(BuildContext context, FamilyEntry? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: AlertDialog(
          // Close to the screen edges and compact, so the Name, Phone and notes fields all fit above the keyboard.
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
          contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          title: Text(existing == null ? _addTitle : 'Edit', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
              if (widget.showPhone) ...[
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              ],
              const SizedBox(height: 10),
              TextField(controller: note, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: widget.noteLabel)),
              const SizedBox(height: 4),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final entry = FamilyEntry(id: existing?.id ?? FamilyStore.newId(), name: n, phone: phone.text.trim(), note: note.text.trim());
    if (saved == true && n.isNotEmpty) await store.upsert(kind, entry);
  }
}

/// Gold (primary) or green (secondary) pill button used on the Family summary card.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.sub, required this.gold, required this.onTap});
  final IconData icon;
  final String label;
  final String sub;
  final bool gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = gold ? const Color(0xFF2B1D06) : const Color(0xFFF1D58A);
    return Semantics(
      button: true,
      label: '$label, $sub',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFF1D58A), width: 1.4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gold ? const [Color(0xFFEBC66B), Color(0xFF9A7324)] : const [Color(0xFF2F6D3B), Color(0xFF14361F)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            // 56 is a minimum: the button grows with the text, and the text shrinks to fit the width, so a large
            // system text size can no longer overflow the button.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: fg, size: 28),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 30, color: fg.withValues(alpha: 0.45)),
                    const SizedBox(width: 10),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.6)),
                      Text(sub, style: TextStyle(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 9.5, letterSpacing: 0.9)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry to the encrypted documents vault (IDs, insurance, medical records): a picture banner.
class _VaultTile extends StatelessWidget {
  const _VaultTile();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Documents Vault. Locked storage for IDs, insurance and medical records. Opens with your fingerprint or screen lock.',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/home/vault_banner.jpg', fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.medium),
            DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.outline, width: 1.5))),
            Positioned(
              right: 12,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xCC061410), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.7))),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_rounded, size: 14, color: AppTheme.accent),
                    SizedBox(width: 5),
                    Text('Tap to unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                  ]),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultScreen()))),
            ),
          ]),
        ),
      ),
    );
  }
}
