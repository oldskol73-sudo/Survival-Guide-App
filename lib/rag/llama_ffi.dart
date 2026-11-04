// dart:ffi bindings for native/llama_shim/sn_llama.h.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef SnTokenCbNative = Void Function(Pointer<Utf8> piece, Int32 len);

class SnErr {
  static const ok = 0, notLoaded = -1, load = -2, context = -3, tooLong = -4, template = -5, decode = -6, cancelled = -7;
}

class LlamaBindings {
  LlamaBindings(DynamicLibrary lib)
      : load = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Int32, Int32, Int32), int Function(Pointer<Utf8>, int, int, int)>('sn_llm_load'),
        isLoaded = lib.lookupFunction<Int32 Function(), int Function()>('sn_llm_is_loaded'),
        nCtx = lib.lookupFunction<Int32 Function(), int Function()>('sn_llm_n_ctx'),
        countPromptTokens = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>), int Function(Pointer<Utf8>, Pointer<Utf8>)>('sn_llm_count_prompt_tokens'),
        generate = lib.lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Float, Uint32, Pointer<NativeFunction<SnTokenCbNative>>),
            int Function(Pointer<Utf8>, Pointer<Utf8>, int, double, int, Pointer<NativeFunction<SnTokenCbNative>>)>('sn_llm_generate'),
        cancel = lib.lookupFunction<Void Function(), void Function()>('sn_llm_cancel'),
        unload = lib.lookupFunction<Void Function(), void Function()>('sn_llm_unload'),
        lastError = lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sn_llm_last_error');

  final int Function(Pointer<Utf8>, int, int, int) load;
  final int Function() isLoaded;
  final int Function() nCtx;
  final int Function(Pointer<Utf8>, Pointer<Utf8>) countPromptTokens;
  final int Function(Pointer<Utf8>, Pointer<Utf8>, int, double, int, Pointer<NativeFunction<SnTokenCbNative>>) generate;
  final void Function() cancel;
  final void Function() unload;
  final Pointer<Utf8> Function() lastError;

  /// Android: libsn_llama.so from the Gradle CMake build. iOS: compiled into Runner, so symbols are in-process.
  static LlamaBindings? tryOpen() {
    try {
      final lib = Platform.isAndroid ? DynamicLibrary.open('libsn_llama.so') : DynamicLibrary.process();
      return LlamaBindings(lib);
    } catch (_) {
      return null; // native library absent: the app runs retrieval-only
    }
  }
}
