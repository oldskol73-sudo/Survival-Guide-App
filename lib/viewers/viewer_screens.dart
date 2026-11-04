// Stage-B viewers: PDF reader (PDFium), ZIM reader (WebView over loopback), offline map (MapLibre).
// Each is wrapped in AirGapGate by the router in main.dart.

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../catalog/catalog_models.dart';
import '../core/settings.dart';
import '../core/storage_paths.dart';
import '../core/theme.dart';
import '../downloads/download_engine.dart';
import 'loopback_server.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.item, this.page = 1});
  final CatalogItem item;
  final int page;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final Future<bool> _ok = _check();

  Future<bool> _check() async {
    if (!AppSettings.instance.verifyOnOpen) return true;
    return DownloadEngine.instance.verifyBeforeOpen(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<bool>(
        future: _ok,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: Text('Verifying file integrity…'));
          if (snap.data == false) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('This file no longer matches its recorded SHA-256. It may have been edited or corrupted. Re-download it before relying on it.',
                  style: TextStyle(color: AppTheme.danger)),
            );
          }
          return PdfViewer.file(
            StoragePaths.instance.resolve(widget.item.target),
            initialPageNumber: widget.page,
            params: const PdfViewerParams(backgroundColor: AppTheme.bg),
          );
        },
      ),
    );
  }
}

class ZimScreen extends StatefulWidget {
  const ZimScreen({super.key, required this.item});
  final CatalogItem item;

  @override
  State<ZimScreen> createState() => _ZimScreenState();
}

class _ZimScreenState extends State<ZimScreen> {
  late final WebViewController _c;

  @override
  void initState() {
    super.initState();
    final server = LoopbackServer.instance!;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // ZIM pages use JS for collapsible sections
      ..setBackgroundColor(AppTheme.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // Only our own loopback origin. External links in Wikipedia articles are refused.
          final u = Uri.tryParse(req.url);
          final ok = u != null && u.host == '127.0.0.1' && u.port == server.port;
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('External link blocked (air-gap)')));
          }
          return ok ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(server.zimUrl(widget.item.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title), actions: [
        IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => _c.goBack()),
      ]),
      body: WebViewWidget(controller: _c),
    );
  }
}

class OfflineMapScreen extends StatelessWidget {
  const OfflineMapScreen({super.key, required this.item, this.center = const LatLng(39.0, -77.5), this.zoom = 9});
  final CatalogItem item;
  final LatLng center;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final server = LoopbackServer.instance!;
    final lowPower = AppSettings.instance.lowPowerMode;
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: MapLibreMap(
        styleString: server.styleUrl(item.id),
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        myLocationEnabled: !lowPower, // GPS is receive-only; off in low-power mode to save battery
        compassEnabled: true,
        rotateGesturesEnabled: !lowPower,
        tiltGesturesEnabled: false,
      ),
    );
  }
}
