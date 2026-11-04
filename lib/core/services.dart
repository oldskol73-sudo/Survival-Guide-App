// Mutable service registry shared by main.dart and the UI.

import '../catalog/catalog_models.dart';
import '../core/model_tier.dart';
import '../core/settings.dart';
import '../core/storage_paths.dart';
import '../downloads/download_engine.dart';
import '../rag/embedder.dart';
import '../rag/llm_worker.dart';
import '../rag/rag_pipeline.dart';
import '../rag/vector_store.dart';
import '../search/fts_index.dart';

/// Mutable service registry: models can arrive after launch (downloaded in Stage A), so the RAG
/// pipeline is assembled on demand from whatever is available right now.
class Services {
  Services._();
  static late Catalog catalog;
  static late FtsIndex fts;
  static late VectorStore vectors;
  static Embedder? embedder;
  static LlmWorker? llm;
  static late ModelTier tier;
  static EmbeddingScheduler? scheduler;

  static String? usableModelPath() {
    String? pathFor(String? tier) {
      for (final i in catalog.allItems.where((i) => i.kind == CategoryKind.model && i.tier != null)) {
        if (tier != null && i.tier != tier) continue;
        if (DownloadEngine.instance.jobs[i.id]?.isUsable ?? false) return StoragePaths.instance.resolve(i.target);
      }
      return null;
    }

    // Preferred tier first; a large-tier phone can always run the small model.
    return pathFor(tier.catalogTier) ?? (tier.tier == LlmTier.large ? pathFor('small') : null);
  }

  static RagPipeline pipeline() => RagPipeline(
        fts: fts,
        vectors: vectors,
        embedder: embedder,
        llm: llm,
        tier: tier,
        modelPath: usableModelPath(),
      );

  static Future<void> ensureEmbedder() async {
    if (embedder != null) return;
    final p = StoragePaths.instance;
    embedder = await Embedder.start(
      modelPath: p.resolve('@models/embed/all-MiniLM-L6-v2.onnx'),
      vocabPath: p.resolve('@models/embed/vocab.txt'),
      threads: AppSettings.instance.lowPowerMode ? 1 : 2,
    );
    if (embedder != null) {
      scheduler = EmbeddingScheduler(fts, vectors, embedder!,
          isAllowed: () => AppSettings.instance.backgroundEmbedding && !AppSettings.instance.lowPowerMode);
    }
  }

  static Future<void> refreshTier() async {
    tier = await ModelTier.select(lowPower: AppSettings.instance.lowPowerMode);
    if (tier.canGenerate) {
      llm ??= await LlmWorker.spawn();
    } else {
      await llm?.unload();
    }
  }
}
