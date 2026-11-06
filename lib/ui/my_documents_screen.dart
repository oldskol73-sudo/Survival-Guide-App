// My Documents: PDFs the user added themselves. Open, add more, or remove (removing deletes only the app's copy).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../catalog/my_documents.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../viewers/viewer_screens.dart';

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<File>? _files;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final f = await MyDocuments.list();
    if (mounted) setState(() => _files = f);
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final r = await MyDocuments.pickAndAdd();
      if (!mounted) return;
      if (r != null) {
        final msg = r.added == 0
            ? 'Nothing new added${r.skipped > 0 ? ' (${r.skipped} already here or not a PDF)' : ''}'
            : 'Added ${r.added} PDF${r.added == 1 ? '' : 's'} and made ${r.added == 1 ? 'it' : 'them'} searchable';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(File f) {
    final target = '${MyDocuments.dirName}/${p.basename(f.path)}';
    for (final i in Services.catalog.localItems) {
      if (i.target == target) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(item: i)));
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Still preparing this file. Try again in a moment.')));
  }

  Future<void> _remove(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove this PDF?'),
        content: Text('${p.basenameWithoutExtension(f.path)}\n\nThis deletes the copy inside Blackout IQ. Your original file is not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await MyDocuments.remove(f);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: const Text('Add PDFs'),
      ),
      body: files == null
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'Add your own PDFs: manuals, maps, medical notes, family papers.\n\n'
                      'They are copied onto this phone, become searchable with everything else, and never leave it. '
                      'Only add files you have the right to keep.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, height: 1.4),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = files[i];
                    final mb = f.lengthSync() / 1048576;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accent),
                        title: Text(p.basenameWithoutExtension(f.path), maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB', style: const TextStyle(color: AppTheme.muted)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(f)),
                        onTap: () => _open(f),
                      ),
                    );
                  },
                ),
    );
  }
}
