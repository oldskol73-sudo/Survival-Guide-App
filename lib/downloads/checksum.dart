// Streaming SHA-256 on a background isolate. Memory use is constant (1 MB buffer) whether the file is a
// 2 MB PDF or a 100 GB ZIM, and the UI isolate never blocks.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Returns the lowercase hex SHA-256 of the file at [path].
Future<String> sha256OfFile(String path) => Isolate.run(() => _hashSync(path));

String _hashSync(String path) {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  final raf = File(path).openSync();
  try {
    final buf = Uint8List(1 << 20);
    while (true) {
      final n = raf.readIntoSync(buf);
      if (n == 0) break;
      // The hash sink copies what it needs, so reusing [buf] is safe.
      input.add(n == buf.length ? buf : Uint8List.sublistView(buf, 0, n));
    }
  } finally {
    raf.closeSync();
  }
  input.close();
  return sink.value.toString();
}

/// Parses a checksum sidecar such as "e3b0c4...  wikipedia_en_all_nopic_2026-09.zim" or a bare hash.
String? parseSha256Sidecar(String body) {
  final m = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(body);
  return m?.group(1)?.toLowerCase();
}

/// Constant-time comparison so timing does not leak how many leading characters matched.
bool hashesEqual(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
