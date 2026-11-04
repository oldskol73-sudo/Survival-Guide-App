// Step By Step Problem Solver: pick an area, describe the problem, say what you have, get numbered steps.

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/theme.dart';
import '../rag/rag_controller.dart';
import 'rag_result.dart';

/// Area chip label -> catalog category id (null = search the whole library).
const _areas = <(String, String?)>[
  ('Water', 'water'),
  ('Food', 'food'),
  ('Medical', 'medical'),
  ('Power', 'energy'),
  ('Repairs', 'mechanical'),
  ('Vehicle', 'transport'),
  ('Shelter', 'carpentry'),
  ('Radio', 'comms'),
  ('Long term', 'longterm'),
  ('Not sure', null),
];

const _stepsInstruction = 'Answer as a numbered list of short steps in the order to do them. '
    'Start with any safety warning. Each step must cite its source tag. '
    'Use the items the person has where the sources allow.';

class ProblemSolverScreen extends StatefulWidget {
  const ProblemSolverScreen({super.key});
  @override
  State<ProblemSolverScreen> createState() => _ProblemSolverScreenState();
}

class _ProblemSolverScreenState extends State<ProblemSolverScreen> {
  final _problem = TextEditingController();
  final _have = TextEditingController();
  int _area = _areas.length - 1;

  @override
  void dispose() {
    _problem.dispose();
    _have.dispose();
    super.dispose();
  }

  void _solve(RagController rag) {
    final problem = _problem.text.trim();
    if (problem.isEmpty) return;
    final have = _have.text.trim();
    rag.ask(
      problem,
      category: _areas[_area].$2,
      instruction: have.isEmpty ? _stepsInstruction : 'The person has: $have.\n$_stepsInstruction',
    );
  }

  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent);
    return Scaffold(
      appBar: AppBar(title: const Text('Step By Step Problem Solver')),
      body: RagBuilder(
        pipeline: Services.pipeline,
        builder: (context, rag) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('1. What is it about?', style: heading),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (var i = 0; i < _areas.length; i++)
                ChoiceChip(label: Text(_areas[i].$1), selected: _area == i, onSelected: (_) => setState(() => _area = i)),
            ]),
            const SizedBox(height: 20),
            const Text('2. Describe the problem', style: heading),
            const SizedBox(height: 8),
            TextField(controller: _problem, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'My only water source is a muddy stream')),
            const SizedBox(height: 20),
            const Text('3. What do you have? (optional)', style: heading),
            const SizedBox(height: 8),
            TextField(controller: _have, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Pot, lighter, cotton cloth, a little bleach')),
            const SizedBox(height: 16),
            RagButton(rag: rag, label: 'Show me the steps', onPressed: () => _solve(rag)),
            RagResult(rag: rag),
          ],
        ),
      ),
    );
  }
}
