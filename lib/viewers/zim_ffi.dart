// dart:ffi bindings for native/zim_shim/sn_zim.cpp.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class ZimEntry {
  ZimEntry(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class ZimLib {
  ZimLib._(DynamicLibrary l)
      : _open = l.lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>('sn_zim_open'),
        _close = l.lookupFunction<Void Function(Int32), void Function(int)>('sn_zim_close'),
        _main = l.lookupFunction<Int32 Function(Int32, Pointer<Utf8>, Int32), int Function(int, Pointer<Utf8>, int)>('sn_zim_main_path'),
        _get = l.lookupFunction<
            Int32 Function(Int32, Pointer<Utf8>, Pointer<Pointer<Uint8>>, Pointer<Int64>, Pointer<Utf8>, Int32),
            int Function(int, Pointer<Utf8>, Pointer<Pointer<Uint8>>, Pointer<Int64>, Pointer<Utf8>, int)>('sn_zim_get'),
        _suggest = l.lookupFunction<Int32 Function(Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Int32), int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)>('sn_zim_suggest'),
        _free = l.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('sn_zim_free'),
        _err = l.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('sn_zim_last_error');

  final int Function(Pointer<Utf8>) _open;
  final void Function(int) _close;
  final int Function(int, Pointer<Utf8>, int) _main;
  final int Function(int, Pointer<Utf8>, Pointer<Pointer<Uint8>>, Pointer<Int64>, Pointer<Utf8>, int) _get;
  final int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int) _suggest;
  final void Function(Pointer<Void>) _free;
  final Pointer<Utf8> Function() _err;

  static ZimLib? _instance;
  static ZimLib? get instance {
    if (_instance != null) return _instance;
    try {
      return _instance = ZimLib._(Platform.isAndroid ? DynamicLibrary.open('libsn_zim.so') : DynamicLibrary.process());
    } catch (_) {
      return null; // built without libzim: the ZIM tab is hidden
    }
  }

  int open(String path) => using((a) {
        final h = _open(path.toNativeUtf8(allocator: a));
        if (h < 0) throw StateError('ZIM open failed: ${_err().toDartString()}');
        return h;
      });

  void close(int h) => _close(h);

  String? mainPath(int h) => using((a) {
        final out = a<Uint8>(2048).cast<Utf8>();
        return _main(h, out, 2048) == 0 ? out.toDartString() : null;
      });

  /// null = not found.
  ZimEntry? get(int h, String path) => using((a) {
        final pData = a<Pointer<Uint8>>();
        final pSize = a<Int64>();
        final mime = a<Uint8>(256).cast<Utf8>();
        final rc = _get(h, path.toNativeUtf8(allocator: a), pData, pSize, mime, 256);
        if (rc == 1) return null;
        if (rc != 0) throw StateError('ZIM read failed: ${_err().toDartString()}');
        try {
          // Copy into Dart memory, then release the native buffer.
          return ZimEntry(Uint8List.fromList(pData.value.asTypedList(pSize.value)), mime.toDartString());
        } finally {
          _free(pData.value.cast());
        }
      });

  List<(String path, String title)> suggest(int h, String query, {int max = 20}) => using((a) {
        const cap = 64 * 1024;
        final out = a<Uint8>(cap).cast<Utf8>();
        final n = _suggest(h, query.toNativeUtf8(allocator: a), max, out, cap);
        if (n <= 0) return const [];
        return [
          for (final line in out.toDartString().split('\n'))
            if (line.contains('\t')) (line.substring(0, line.indexOf('\t')), line.substring(line.indexOf('\t') + 1)),
        ];
      });
}
