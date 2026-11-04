// Documents vault UI: lock gate -> document list -> editor with encrypted photos -> full-screen viewer.
// The vault locks the moment the user leaves this screen or the app goes to the background.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import 'vault_store.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  final _store = VaultStore.instance;
  UnlockResult? _last;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStoreChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  /// When the vault locks (timeout, background, Lock button), close any editor or photo opened above this
  /// screen so decrypted content is never left on screen.
  void _onStoreChange() {
    if (_store.unlocked || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).popUntil((r) => r == route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock as soon as the app is hidden (home button, app switcher, screen off). A system auth prompt also
    // pauses the app, so only lock when we are already unlocked.
    if (state == AppLifecycleState.paused && _store.unlocked) _store.lock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChange);
    unawaited(_store.lock());
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _store.unlocked) return;
    setState(() => _busy = true);
    final r = await _store.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _last = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => _store.unlocked ? _VaultList(store: _store) : _Locked(result: _last, busy: _busy, onUnlock: _unlock),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.result, required this.busy, required this.onUnlock});
  final UnlockResult? result;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final message = switch (result) {
      UnlockResult.noDeviceLock => 'This phone has no screen lock. Set a PIN, pattern, password or fingerprint in your phone settings, then come back. The vault will not open without one.',
      UnlockResult.failed => 'Could not unlock. Try again.',
      _ => 'Your documents are encrypted on this phone and never uploaded.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Documents Vault')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: AppTheme.accentSoft, shape: BoxShape.circle, border: Border.all(color: AppTheme.outline)),
              child: const Icon(Icons.lock_rounded, size: 48, color: AppTheme.accent),
            ),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: result == UnlockResult.noDeviceLock ? AppTheme.warn : AppTheme.muted)),
            const SizedBox(height: 24),
            if (result != UnlockResult.noDeviceLock)
              FilledButton.icon(
                onPressed: busy ? null : onUnlock,
                style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
                icon: const Icon(Icons.fingerprint),
                label: Text(busy ? 'Unlocking…' : 'Unlock'),
              ),
          ]),
        ),
      ),
    );
  }
}

class _VaultList extends StatelessWidget {
  const _VaultList({required this.store});
  final VaultStore store;

  @override
  Widget build(BuildContext context) {
    final docs = store.docs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents Vault'),
        actions: [
          IconButton(tooltip: 'Lock now', icon: const Icon(Icons.lock_outline), onPressed: store.lock),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'erase' && await _confirmErase(context)) await store.eraseAll();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'erase', child: Text('Erase vault'))],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DocEditor(store: store))),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: docs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.muted),
                  SizedBox(height: 12),
                  Text('Nothing here yet. Add copies of your ID, insurance cards and medical records.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final cat in DocCategory.values)
                  if (docs.any((d) => d.category == cat)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(cat.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                    ),
                    for (final d in docs.where((d) => d.category == cat))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined, color: AppTheme.accent),
                          title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${d.files.length} ${d.files.length == 1 ? 'photo' : 'photos'}${d.notes.isEmpty ? '' : ' · ${d.notes.split('\n').first}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DocEditor(store: store, existing: d))),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }

  Future<bool> _confirmErase(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erase the whole vault?'),
          content: const Text('Every document and photo is permanently deleted from this phone. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.sos, foregroundColor: Colors.white), child: const Text('Erase')),
          ],
        ),
      ) ??
      false;
}

class _DocEditor extends StatefulWidget {
  const _DocEditor({required this.store, this.existing});
  final VaultStore store;
  final VaultDoc? existing;
  @override
  State<_DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<_DocEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DocCategory _cat = widget.existing?.category ?? DocCategory.identity;
  late final List<String> _files = [...?widget.existing?.files];
  final Set<String> _added = {}; // photos added in this session (removed again if the user cancels)
  final Map<String, Uint8List> _thumbs = {};
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    for (final id in _files) {
      _load(id);
    }
  }

  Future<void> _load(String id) async {
    final bytes = await widget.store.readPhoto(id);
    if (mounted) setState(() => _thumbs[id] = bytes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    // Leaving without saving: forget photos that were only added in this session.
    if (!_saved) {
      for (final id in _added) {
        unawaited(widget.store.deletePhoto(id));
      }
    }
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2200, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final id = await widget.store.addPhoto(bytes);
    if (!mounted) return;
    setState(() {
      _files.add(id);
      _added.add(id);
      _thumbs[id] = bytes;
    });
  }

  void _removePhoto(String id) {
    // The blob is only deleted on Save (existing photos) or immediately (new ones), so Cancel is safe.
    setState(() => _files.remove(id));
    if (_added.remove(id)) unawaited(widget.store.deletePhoto(id));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the document a title.')));
      return;
    }
    final e = widget.existing;
    // Photos removed from an existing document are erased now that the user confirmed.
    if (e != null) {
      for (final id in e.files.where((id) => !_files.contains(id))) {
        await widget.store.deletePhoto(id);
      }
    }
    final doc = VaultDoc(id: e?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), title: title, category: _cat, notes: _notes.text.trim(), files: _files, created: e?.created);
    await widget.store.upsert(doc);
    _saved = true;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.existing!.title}?'),
        content: const Text('Its photos are permanently erased.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.delete(widget.existing!);
    _saved = true;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add document' : 'Edit document'),
        actions: [
          if (widget.existing != null) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Title', hintText: 'Passport, health insurance card…')),
          const SizedBox(height: 16),
          const Text('Category', style: heading),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in DocCategory.values) ChoiceChip(label: Text(c.label), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _notes, minLines: 3, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Details', hintText: 'Policy or ID number, expiry date, phone to call…')),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Photos', style: heading)),
            TextButton.icon(onPressed: () => _addPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
            TextButton.icon(onPressed: () => _addPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
          ]),
          const SizedBox(height: 8),
          if (_files.isEmpty)
            const Text('No photos yet. Photograph both sides of a card or each page of a document.', style: TextStyle(color: AppTheme.muted))
          else
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final id in _files)
                  Stack(fit: StackFit.expand, children: [
                    GestureDetector(
                      onTap: _thumbs[id] == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PhotoViewer(bytes: _thumbs[id]!))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _thumbs[id] == null ? const ColoredBox(color: AppTheme.card, child: Center(child: CircularProgressIndicator(strokeWidth: 2))) : Image.memory(_thumbs[id]!, fit: BoxFit.cover, cacheWidth: 400),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(customBorder: const CircleBorder(), onTap: () => _removePhoto(id), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18, color: Colors.white))),
                      ),
                    ),
                  ]),
              ],
            ),
        ],
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(child: InteractiveViewer(maxScale: 6, child: Image.memory(bytes))),
      );
}
