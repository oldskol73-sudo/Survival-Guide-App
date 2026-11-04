import 'package:flutter/material.dart';

import '../core/services.dart';
import '../rag/rag_controller.dart';
import 'rag_result.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Answer Questions')),
      body: RagBuilder(
        pipeline: Services.pipeline,
        builder: (context, rag) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _q,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Ask the library', hintText: 'How do I make river water safe to drink?'),
            ),
            const SizedBox(height: 12),
            RagButton(rag: rag, label: 'Ask', onPressed: () => rag.ask(_q.text)),
            RagResult(rag: rag),
          ],
        ),
      ),
    );
  }
}
