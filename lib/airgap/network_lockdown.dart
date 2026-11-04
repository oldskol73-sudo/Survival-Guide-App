// App-level enforcement for Stage B. Once sealed, every dart:io HttpClient in the process (ours and any
// package's) can only reach loopback. This does not replace airplane mode; it guarantees the app itself
// cannot leak even if a radio is accidentally left on.
//
// Limits: native code that opens its own sockets (not via dart:io) is not covered. That is why:
//   * the app ships no analytics or crash-reporting SDKs, and llama.cpp is built with LLAMA_CURL=OFF;
//   * the WebView (ZIM reader) blocks non-loopback navigations and the loopback server sends a strict CSP;
//   * the MapLibre style references only loopback URLs (tiles, glyphs, sprites).

import 'dart:io';

class AirGapViolation implements Exception {
  AirGapViolation(this.host);
  final String host;
  @override
  String toString() => 'AirGapViolation: blocked connection to $host while the node is sealed';
}

class NetworkLockdown extends HttpOverrides {
  NetworkLockdown._();
  static bool _active = false;
  static bool get isActive => _active;
  static final List<String> blockedLog = []; // shown in Settings > Air-gap log

  static void engage() {
    HttpOverrides.global = NetworkLockdown._();
    _active = true;
  }

  static void release() {
    HttpOverrides.global = null;
    _active = false;
  }

  static bool isLoopback(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]' || host.startsWith('127.');

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = super.createHttpClient(context);
    inner.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
      final host = proxyHost ?? uri.host;
      if (!isLoopback(host)) {
        blockedLog.add('${DateTime.now().toIso8601String()}  $host');
        if (blockedLog.length > 200) blockedLog.removeAt(0);
        return Future<ConnectionTask<Socket>>.error(AirGapViolation(host));
      }
      // HttpClient requires a SecureSocket for https URLs.
      return uri.scheme == 'https'
          ? SecureSocket.startConnect(host, uri.port, context: context)
          : Socket.startConnect(host, uri.port);
    };
    inner.findProxy = (_) => 'DIRECT';
    return inner;
  }
}
