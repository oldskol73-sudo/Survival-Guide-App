// Owns the llama.cpp model on a dedicated isolate. sn_llm_generate() blocks that isolate's thread
// while it streams; each token arrives through a synchronous FFI callback and is forwarded to the
// UI isolate over a SendPort. Cancellation calls the C atomic flag directly from the UI isolate.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'llama_ffi.dart';

sealed class LlmEvent {}

class LlmToken extends LlmEvent {
  LlmToken(this.text);
  final String text;
}

class LlmDone extends LlmEvent {
  LlmDone(this.tokens, {this.cancelled = false});
  final int tokens;
  final bool cancelled;
}

class LlmError extends LlmEvent {
  LlmError(this.code, this.message);
  final int code;
  final String message;
}

class LlmWorker {
  LlmWorker._(this._cmd, this._isolate, this._bindingsForCancel);

  final SendPort _cmd;
  final Isolate _isolate;
  final LlamaBindings _bindingsForCancel;
  bool _busy = false;
  String? loadedPath;

  static Future<LlmWorker?> spawn() async {
    final b = LlamaBindings.tryOpen();
    if (b == null) return null;
    final rp = ReceivePort();
    final iso = await Isolate.spawn(_main, rp.sendPort, debugName: 'llm');
    final cmd = await rp.first as SendPort;
    return LlmWorker._(cmd, iso, b);
  }

  Future<T> _call<T>(Map<String, Object?> msg) async {
    final rp = ReceivePort();
    _cmd.send({...msg, 'reply': rp.sendPort});
    final r = await rp.first;
    rp.close();
    return r as T;
  }

  /// Returns null on success, else an error message.
  Future<String?> load(String path, {required int nCtx, required int threads, required int gpuLayers}) async {
    if (loadedPath == path) return null;
    final r = await _call<List>({'cmd': 'load', 'path': path, 'nCtx': nCtx, 'threads': threads, 'gpu': gpuLayers});
    if (r[0] == SnErr.ok) {
      loadedPath = path;
      return null;
    }
    loadedPath = null;
    return r[1] as String;
  }

  Future<int> countPromptTokens(String system, String user) =>
      _call<int>({'cmd': 'count', 'system': system, 'user': user});

  Future<void> unload() async {
    if (_busy) cancel();
    await _call<int>({'cmd': 'unload'});
    loadedPath = null;
  }

  /// Streams the answer. Only one generation runs at a time.
  Stream<LlmEvent> generate(String system, String user, {required int maxTokens, double temperature = 0.2}) {
    final out = StreamController<LlmEvent>();
    if (_busy) {
      out
        ..add(LlmError(-100, 'A generation is already running'))
        ..close();
      return out.stream;
    }
    _busy = true;
    final rp = ReceivePort();
    rp.listen((m) {
      final msg = m as List;
      switch (msg[0]) {
        case 't':
          out.add(LlmToken(msg[1] as String));
        case 'done':
          final n = msg[1] as int;
          if (n >= 0) {
            out.add(LlmDone(n));
          } else if (n == SnErr.cancelled) {
            out.add(LlmDone(0, cancelled: true));
          } else {
            out.add(LlmError(n, msg[2] as String));
          }
          _busy = false;
          rp.close();
          out.close();
      }
    });
    out.onCancel = cancel; // UI stopped listening: stop burning CPU
    _cmd.send({'cmd': 'gen', 'system': system, 'user': user, 'max': maxTokens, 'temp': temperature, 'reply': rp.sendPort});
    return out.stream;
  }

  /// Safe from any isolate: flips an atomic in C, checked between tokens.
  void cancel() => _bindingsForCancel.cancel();

  void dispose() {
    cancel();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  // ------------------------------------------------------------------ worker isolate

  static SendPort? _streamTo;
  static final _decoder = const Utf8Decoder(allowMalformed: true);

  static void _onToken(Pointer<Utf8> piece, int len) {
    final bytes = piece.cast<Uint8>().asTypedList(len);
    _streamTo?.send(['t', _decoder.convert(bytes)]);
  }

  static void _main(SendPort boot) {
    final b = LlamaBindings.tryOpen()!;
    final cb = Pointer.fromFunction<SnTokenCbNative>(_onToken);
    final inbox = ReceivePort();
    boot.send(inbox.sendPort);

    String err() => b.lastError().toDartString();

    inbox.listen((m) {
      final msg = m as Map;
      final reply = msg['reply'] as SendPort;
      switch (msg['cmd']) {
        case 'load':
          final path = (msg['path'] as String).toNativeUtf8();
          final rc = b.load(path, msg['nCtx'] as int, msg['threads'] as int, msg['gpu'] as int);
          malloc.free(path);
          reply.send([rc, rc == SnErr.ok ? '' : err()]);
        case 'count':
          final s = (msg['system'] as String).toNativeUtf8();
          final u = (msg['user'] as String).toNativeUtf8();
          final n = b.countPromptTokens(s, u);
          malloc
            ..free(s)
            ..free(u);
          reply.send(n);
        case 'gen':
          final s = (msg['system'] as String).toNativeUtf8();
          final u = (msg['user'] as String).toNativeUtf8();
          _streamTo = reply;
          final n = b.generate(s, u, msg['max'] as int, (msg['temp'] as num).toDouble(), DateTime.now().millisecondsSinceEpoch & 0x7fffffff, cb);
          _streamTo = null;
          malloc
            ..free(s)
            ..free(u);
          reply.send(['done', n, n < 0 && n != SnErr.cancelled ? err() : '']);
        case 'unload':
          b.unload();
          reply.send(0);
      }
    });
  }
}
