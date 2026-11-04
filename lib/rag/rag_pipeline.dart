// Air-gapped RAG: embed question -> hybrid retrieval (vector + FTS5, reciprocal-rank fusion) ->
// top-3 passages -> prompt sized to the context window -> streamed answer with [S#] citations.
// If no model can run (RAM tier, missing files, memory pressure) it returns retrieval-only results.

import 'dart:async';
import 'dart:io';

import '../core/model_tier.dart';
import '../search/fts_index.dart';
import 'embedder.dart';
import 'llm_worker.dart';
import 'vector_store.dart';

class Source {
  Source(this.n, this.itemId, this.title, this.page, this.text);
  final int n; // citation number shown as [S1]
  final String itemId;
  final String title;
  final int page;
  final String text;
  String get citation => '$title, p. $page';
}

sealed class RagEvent {}

class RagStatus extends RagEvent {
  RagStatus(this.message);
  final String message;
}

class RagSources extends RagEvent {
  RagSources(this.sources);
  final List<Source> sources;
}

class RagToken extends RagEvent {
  RagToken(this.text);
  final String text;
}

class RagDone extends RagEvent {
  RagDone({required this.retrievalOnly, this.reason, this.cancelled = false});
  final bool retrievalOnly;
  final String? reason;
  final bool cancelled;
}

class RagFailure extends RagEvent {
  RagFailure(this.message);
  final String message;
}

const _systemPrompt = '''
You are an offline field reference assistant. Answer ONLY from the numbered sources provided.
Give exact procedures, quantities and units as written in the sources. Cite every fact with its
source tag, for example [S1] or [S2]. If the sources do not contain the answer, reply exactly:
"The library does not cover this." Do not guess. For medical, chemical or electrical steps, remind
the reader to confirm against the cited page.''';

class RagPipeline {
  RagPipeline({required this.fts, required this.vectors, required this.embedder, required this.llm, required this.tier, required this.modelPath});

  final FtsIndex fts;
  final VectorStore? vectors;
  final Embedder? embedder;
  final LlmWorker? llm;
  ModelTier tier;
  final String? modelPath;

  /// Called by the UI layer on didHaveMemoryPressure: free the model now, reload on next question if possible.
  Future<void> onMemoryPressure() async {
    await llm?.unload();
  }

  Stream<RagEvent> ask(String question, {String? category, int topN = 3, String? instruction}) async* {
    final q = question.trim();
    if (q.isEmpty) return;

    // 1. Retrieve.
    yield RagStatus('Searching the library…');
    final sources = await _retrieve(q, category: category, topN: topN);
    if (sources.isEmpty) {
      yield RagSources(const []);
      yield RagDone(retrievalOnly: true, reason: 'No matching passages in the library.');
      return;
    }
    yield RagSources(sources);

    // 2. Decide whether generation is possible.
    final reason = _cannotGenerateReason();
    if (reason != null) {
      yield RagDone(retrievalOnly: true, reason: reason);
      return;
    }
    yield RagStatus('Loading model…');
    final loadErr = await llm!.load(modelPath!, nCtx: tier.nCtx, threads: tier.threads, gpuLayers: _gpuLayers);
    if (loadErr != null) {
      yield RagDone(retrievalOnly: true, reason: 'Model could not load ($loadErr). Showing passages only.');
      return;
    }

    // 3. Build a prompt that fits: prompt + reply + margin must fit n_ctx; drop or trim lowest-ranked sources.
    final budget = tier.nCtx - tier.maxNewTokens - 64;
    var used = List<Source>.of(sources);
    var user = _userPrompt(q, used, instruction);
    while (true) {
      final n = await llm!.countPromptTokens(_systemPrompt, user);
      if (n < 0) {
        yield RagFailure('Tokenizer error ($n)');
        return;
      }
      if (n <= budget) break;
      if (used.length > 1) {
        used = used.sublist(0, used.length - 1);
      } else {
        final s = used.single;
        final cut = (s.text.length * 0.7).floor();
        if (cut < 200) break; // cannot shrink further; generate() will report too-long
        used = [Source(s.n, s.itemId, s.title, s.page, '${s.text.substring(0, cut)}…')];
      }
      user = _userPrompt(q, used, instruction);
    }

    // 4. Stream.
    yield RagStatus('Answering…');
    await for (final e in llm!.generate(_systemPrompt, user, maxTokens: tier.maxNewTokens)) {
      switch (e) {
        case LlmToken(:final text):
          yield RagToken(text);
        case LlmDone(:final cancelled):
          yield RagDone(retrievalOnly: false, cancelled: cancelled);
        case LlmError(:final message):
          yield RagFailure(message);
      }
    }
  }

  void cancel() => llm?.cancel();

  String? _cannotGenerateReason() {
    if (!tier.canGenerate) return 'This device has too little memory for on-device AI. Showing the best passages.';
    if (llm == null) return 'On-device AI is not installed in this build. Showing the best passages.';
    if (modelPath == null) return 'No language model downloaded yet. Showing the best passages.';
    // After a memory warning we try once more on the next question; another warning unloads again.
    return null;
  }

  /// iOS builds link llama.cpp with Metal: offload all layers. Android runs on CPU (Vulkan drivers vary too much).
  int get _gpuLayers => Platform.isIOS ? 99 : 0;

  static String _userPrompt(String q, List<Source> sources, [String? instruction]) {
    final b = StringBuffer('Sources:\n');
    for (final s in sources) {
      b.writeln('[S${s.n}] ${s.title}, page ${s.page}:');
      b.writeln(s.text);
      b.writeln();
    }
    b.writeln('Question: $q');
    if (instruction != null) b.writeln(instruction);
    return b.toString();
  }

  /// Hybrid retrieval. Vector search finds paraphrases ("make water safe" ~ "disinfection");
  /// FTS5 finds exact terms ("FM 21-10", "calcium hypochlorite"). Reciprocal-rank fusion merges them
  /// at page granularity, then the best chunk of each winning page is used as the passage.
  Future<List<Source>> _retrieve(String q, {String? category, required int topN}) async {
    const rrfK = 60.0;
    final scores = <String, double>{};
    final passage = <String, ChunkHit>{};
    final ftsPage = <String, SearchHit>{};

    if (embedder != null && vectors != null) {
      try {
        final qv = await embedder!.embed(q);
        final hits = vectors!.topK(qv, k: 20, category: category);
        for (var i = 0; i < hits.length; i++) {
          final h = hits[i];
          final key = '${h.itemId}#${h.page}';
          scores[key] = (scores[key] ?? 0) + 1 / (rrfK + i + 1);
          passage.putIfAbsent(key, () => h); // hits are sorted, so the first chunk per page is the best
        }
      } catch (_) {
        // Embedding failed (model missing/corrupt): keyword retrieval below still works.
      }
    }

    final fr = fts.searchNatural(q, category: category, limit: 20);
    for (var i = 0; i < fr.hits.length; i++) {
      final h = fr.hits[i];
      final key = '${h.itemId}#${h.page}';
      scores[key] = (scores[key] ?? 0) + 1 / (rrfK + i + 1);
      ftsPage.putIfAbsent(key, () => h);
    }

    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final out = <Source>[];
    for (final e in ranked) {
      if (out.length >= topN) break;
      final c = passage[e.key];
      if (c != null) {
        out.add(Source(out.length + 1, c.itemId, c.title, c.page, c.text));
        continue;
      }
      // FTS-only hit: use the page's first chunk as the passage.
      final f = ftsPage[e.key]!;
      final rows = fts.db.select(
          'SELECT c.text FROM chunks c JOIN documents d ON d.id = c.doc_id WHERE d.item_id = ? AND c.page = ? ORDER BY c.ord LIMIT 1',
          [f.itemId, f.page]);
      if (rows.isEmpty) continue;
      out.add(Source(out.length + 1, f.itemId, f.title, f.page, rows.first['text'] as String));
    }
    return out;
  }
}
