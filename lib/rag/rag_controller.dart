// Flutter equivalent of a React "useRag" hook: a ChangeNotifier that owns one question's lifecycle,
// plus RagBuilder to bind it to widgets. Handles cancel-on-dispose and memory-pressure unloads.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'rag_pipeline.dart';

enum RagPhase { idle, retrieving, generating, done, error }

class RagController extends ChangeNotifier with WidgetsBindingObserver {
  /// [makePipeline] is called per question, so models downloaded after the screen opened are used.
  RagController(this._makePipeline) {
    WidgetsBinding.instance.addObserver(this);
  }

  final RagPipeline Function() _makePipeline;
  RagPipeline? _pipeline;
  StreamSubscription<RagEvent>? _sub;

  RagPhase phase = RagPhase.idle;
  String status = '';
  String answer = '';
  List<Source> sources = const [];
  bool retrievalOnly = false;
  String? notice; // e.g. "Showing passages only" reason
  String? error;

  bool get busy => phase == RagPhase.retrieving || phase == RagPhase.generating;

  void ask(String question, {String? category}) {
    _sub?.cancel();
    phase = RagPhase.retrieving;
    status = '';
    answer = '';
    sources = const [];
    retrievalOnly = false;
    notice = null;
    error = null;
    notifyListeners();

    final pipeline = _pipeline = _makePipeline();
    _sub = pipeline.ask(question, category: category).listen((e) {
      switch (e) {
        case RagStatus(:final message):
          status = message;
          if (message.startsWith('Answering')) phase = RagPhase.generating;
        case RagSources(sources: final s):
          sources = s;
        case RagToken(:final text):
          answer += text;
        case RagDone(retrievalOnly: final ro, :final reason, :final cancelled):
          retrievalOnly = ro;
          notice = reason ?? (cancelled ? 'Stopped.' : null);
          phase = RagPhase.done;
        case RagFailure(:final message):
          error = message;
          phase = RagPhase.error;
      }
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      phase = RagPhase.error;
      notifyListeners();
    });
  }

  void stop() {
    _pipeline?.cancel();
  }

  @override
  void didHaveMemoryPressure() {
    // iOS memory warning / Android onTrimMemory: free ~1 GB of weights immediately.
    stop();
    unawaited((_pipeline ?? _makePipeline()).onMemoryPressure());
    notice = 'Memory was low, so the AI model was unloaded. It will reload for the next question if possible.';
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipeline?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// Usage:  RagBuilder(pipeline: Services.pipeline, builder: (context, rag) => ...)
class RagBuilder extends StatefulWidget {
  const RagBuilder({super.key, required this.pipeline, required this.builder});
  final RagPipeline Function() pipeline;
  final Widget Function(BuildContext context, RagController rag) builder;

  @override
  State<RagBuilder> createState() => _RagBuilderState();
}

class _RagBuilderState extends State<RagBuilder> {
  late final RagController _c = RagController(widget.pipeline);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _c, builder: (ctx, _) => widget.builder(ctx, _c));
}
