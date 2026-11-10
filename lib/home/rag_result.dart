// Shared result view for every AI-backed screen: status, streamed answer, notices and cited sources.

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/theme.dart';
import '../rag/rag_controller.dart';
import '../viewers/viewer_screens.dart';

class RagResult extends StatelessWidget {
  const RagResult({super.key, required this.rag});
  final RagController rag;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (rag.status.isNotEmpty && rag.busy)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(rag.status, style: const TextStyle(color: AppTheme.muted))),
      if (rag.notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(rag.notice!, style: const TextStyle(color: AppTheme.warn))),
      if (rag.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(rag.error!, style: const TextStyle(color: AppTheme.danger))),
      if (rag.answer.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 16), child: SelectableText(rag.answer, style: const TextStyle(fontSize: 16, height: 1.55))),
      if (rag.sources.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Sources', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final s in rag.sources)
          Card(
            child: ListTile(
              leading: Text('S${s.n}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w800)),
              title: Text(s.citation),
              subtitle: Text(s.text, maxLines: rag.retrievalOnly ? 8 : 3, overflow: TextOverflow.ellipsis),
              onTap: () {
                final item = Services.catalog.itemById(s.itemId);
                if (item != null) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(item: item, page: s.page)));
                }
              },
            ),
          ),
      ],
      if (rag.answer.isNotEmpty || rag.sources.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Answers come from the offline library and can be wrong, out of date or not fit your situation. Check the cited page, and call emergency services in an emergency. This is not medical, legal or professional advice.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.muted),
          ),
        ),
    ]);
  }
}

/// Large primary button that doubles as Stop while generating.
class RagButton extends StatelessWidget {
  const RagButton({super.key, required this.rag, required this.label, required this.onPressed});
  final RagController rag;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        // Closing the keyboard first: it otherwise covers the answer, which appears just below this button.
        onPressed: rag.busy
            ? rag.stop
            : onPressed == null
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    onPressed!();
                  },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(rag.busy ? 'Stop' : label),
      );
}
