// 384-d sentence embeddings with ONNX Runtime Mobile (all-MiniLM-L6-v2), on a dedicated isolate so
// inference never stalls the UI. Mean pooling over the attention mask, then L2 normalisation, so
// cosine similarity is a plain dot product downstream.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'wordpiece_tokenizer.dart';

const embeddingDim = 384;

class Embedder {
  Embedder._(this._send, this._isolate);
  final SendPort _send;
  final Isolate _isolate;
  int _nextId = 0;
  final _pending = <int, Completer<List<Float32List>>>{};

  static Embedder? _instance;
  static Embedder? get instance => _instance;

  /// Starts the worker. Returns null (and the app falls back to keyword search) if the model files are absent.
  static Future<Embedder?> start({required String modelPath, required String vocabPath, required int threads}) async {
    if (_instance != null) return _instance;
    if (!File(modelPath).existsSync() || !File(vocabPath).existsSync()) return null;
    final ready = ReceivePort();
    final iso = await Isolate.spawn(_main, [ready.sendPort, modelPath, vocabPath, threads], debugName: 'embedder');
    final events = ready.asBroadcastStream();
    final first = await events.first;
    if (first is String) {
      iso.kill();
      return null; // init error message
    }
    final e = Embedder._(first as SendPort, iso);
    events.listen((msg) {
      final m = msg as List;
      final c = e._pending.remove(m[0] as int);
      if (m[1] is String) {
        c?.completeError(StateError(m[1] as String));
      } else {
        c?.complete((m[1] as List).cast<Float32List>());
      }
    });
    return _instance = e;
  }

  Future<Float32List> embed(String text) async => (await embedBatch([text])).single;

  Future<List<Float32List>> embedBatch(List<String> texts) {
    final id = _nextId++;
    final c = Completer<List<Float32List>>();
    _pending[id] = c;
    _send.send([id, texts]);
    return c.future;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    for (final c in _pending.values) {
      c.completeError(StateError('embedder stopped'));
    }
    _pending.clear();
    _instance = null;
  }

  // ------------------------------------------------------------------ worker isolate

  static Future<void> _main(List<Object> args) async {
    final reply = args[0] as SendPort;
    OrtSession session;
    WordPieceTokenizer tok;
    try {
      OrtEnv.instance.init();
      final opts = OrtSessionOptions()
        ..setIntraOpNumThreads(args[3] as int)
        ..setInterOpNumThreads(1);
      session = OrtSession.fromFile(File(args[1] as String), opts);
      tok = await WordPieceTokenizer.fromVocabFile(args[2] as String);
    } catch (e) {
      reply.send('init failed: $e');
      return;
    }
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    final runOpts = OrtRunOptions();

    await for (final msg in inbox) {
      final m = msg as List;
      final id = m[0] as int;
      try {
        final out = <Float32List>[];
        for (final text in (m[1] as List).cast<String>()) {
          out.add(_embedOne(session, runOpts, tok, text));
        }
        reply.send([id, out]);
      } catch (e) {
        reply.send([id, 'embed failed: $e']);
      }
    }
  }

  static Float32List _embedOne(OrtSession s, OrtRunOptions ro, WordPieceTokenizer tok, String text) {
    final enc = tok.encode(text);
    final shape = [1, enc.length];
    final ids = OrtValueTensor.createTensorWithDataList(enc.inputIds, shape);
    final mask = OrtValueTensor.createTensorWithDataList(enc.attentionMask, shape);
    final types = OrtValueTensor.createTensorWithDataList(enc.tokenTypeIds, shape);
    final inputs = <String, OrtValue>{'input_ids': ids, 'attention_mask': mask};
    if (s.inputNames.contains('token_type_ids')) inputs['token_type_ids'] = types;
    List<OrtValue?> outputs = const [];
    try {
      outputs = s.run(ro, inputs);
      // last_hidden_state: [1][seq][384]
      final hidden = (outputs.first!.value as List)[0] as List;
      final v = Float32List(embeddingDim);
      for (final tokenVec in hidden) {
        final t = tokenVec as List;
        for (var d = 0; d < embeddingDim; d++) {
          v[d] += (t[d] as num).toDouble();
        }
      }
      var norm = 0.0;
      for (var d = 0; d < embeddingDim; d++) {
        v[d] /= hidden.length; // every position is unmasked (single, unpadded sequence)
        norm += v[d] * v[d];
      }
      norm = sqrt(norm);
      if (norm > 0) {
        for (var d = 0; d < embeddingDim; d++) {
          v[d] /= norm;
        }
      }
      return v;
    } finally {
      ids.release();
      mask.release();
      types.release();
      for (final o in outputs) {
        o?.release();
      }
    }
  }
}
