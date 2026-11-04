// Generate Priority Plan: describe the situation, get a ranked plan (most life-threatening first).

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/theme.dart';
import '../rag/rag_controller.dart';
import 'rag_result.dart';

const _planInstruction = 'Write a priority plan as a numbered list, most urgent first. Rank by what '
    'threatens life soonest: immediate danger and bleeding, then shelter and warmth, then water, then '
    'food, then signalling and communication. For each item give the single most important action and '
    'a time frame, and cite its source tag. Only include items the sources support.';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _situation = TextEditingController();
  final _people = TextEditingController(text: '1');
  final _days = TextEditingController(text: '3');
  final _have = TextEditingController();

  @override
  void dispose() {
    _situation.dispose();
    _people.dispose();
    _days.dispose();
    _have.dispose();
    super.dispose();
  }

  void _generate(RagController rag) {
    final s = _situation.text.trim();
    if (s.isEmpty) return;
    final people = _people.text.trim().isEmpty ? '1' : _people.text.trim();
    final days = _days.text.trim().isEmpty ? '3' : _days.text.trim();
    final have = _have.text.trim();
    rag.ask(
      s,
      instruction: 'People: $people. Plan for $days days. '
          '${have.isEmpty ? 'Supplies on hand: not stated.' : 'Supplies on hand: $have.'}\n$_planInstruction',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Priority Plan')),
      body: RagBuilder(
        pipeline: Services.pipeline,
        builder: (context, rag) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('What is happening?', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent)),
            const SizedBox(height: 8),
            TextField(controller: _situation, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'Power out in winter, house is cold, no tap water')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: _people, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'People'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days'))),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _have, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Supplies on hand (optional)')),
            const SizedBox(height: 16),
            RagButton(rag: rag, label: 'Generate plan', onPressed: () => _generate(rag)),
            RagResult(rag: rag),
          ],
        ),
      ),
    );
  }
}
