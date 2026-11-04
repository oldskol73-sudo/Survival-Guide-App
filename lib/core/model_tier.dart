// Chooses LLM size, context and threads from device RAM so low-end phones degrade gracefully
// (smaller model, then retrieval-only) instead of being killed by the OS.

import 'dart:io';
import 'dart:math';

import 'device_info.dart';

enum LlmTier { large, small, smallTight, retrievalOnly }

class ModelTier {
  const ModelTier({required this.tier, required this.nCtx, required this.threads, required this.maxNewTokens});

  final LlmTier tier;
  final int nCtx;
  final int threads;
  final int maxNewTokens;

  bool get canGenerate => tier != LlmTier.retrievalOnly;
  String? get catalogTier => switch (tier) {
        LlmTier.large => 'large',
        LlmTier.small || LlmTier.smallTight => 'small',
        LlmTier.retrievalOnly => null,
      };

  static const _gb = 1024 * 1024 * 1024;

  static Future<ModelTier> select({required bool lowPower}) async {
    final ram = await DeviceInfo.totalRamBytes() ?? 3 * _gb; // unknown = assume low-end
    final cores = await DeviceInfo.cpuCores() ?? Platform.numberOfProcessors;
    // Leave two cores for UI + OS; big.LITTLE phones gain little past the performance cores.
    var threads = max(1, min(6, cores - 2));
    if (lowPower) threads = max(1, threads ~/ 2);
    final tokens = lowPower ? 256 : 512;

    if (ram >= 8 * _gb) return ModelTier(tier: LlmTier.large, nCtx: 4096, threads: threads, maxNewTokens: tokens);
    if (ram >= 6 * _gb) return ModelTier(tier: LlmTier.small, nCtx: 4096, threads: min(threads, 4), maxNewTokens: tokens);
    if (ram >= 4 * _gb) return ModelTier(tier: LlmTier.smallTight, nCtx: 2048, threads: min(threads, 3), maxNewTokens: min(tokens, 384));
    return const ModelTier(tier: LlmTier.retrievalOnly, nCtx: 0, threads: 1, maxNewTokens: 0);
  }
}
