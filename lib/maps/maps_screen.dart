// Offline Maps: choose an area around you, see how big it is, download it, then open it with no signal.
// Downloading needs the network (Stage A) and is unavailable once the node is sealed; viewing never does.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

import '../airgap/airgap_banner.dart';
import '../catalog/catalog_models.dart';
import '../core/device_info.dart';
import '../core/services.dart';
import '../core/settings.dart';
import '../core/storage_paths.dart';
import '../core/theme.dart';
import '../viewers/loopback_server.dart';
import '../viewers/viewer_screens.dart';
import 'map_download.dart';
import 'pmtiles.dart';

String _mb(int bytes) => bytes >= 1073741824 ? '${(bytes / 1073741824).toStringAsFixed(1)} GB' : '${(bytes / 1048576).round()} MB';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});
  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late final Category _category = Services.catalog.categories.firstWhere((c) => c.kind == CategoryKind.map);
  late final CatalogItem _item = _category.items.first;

  final _lat = TextEditingController();
  final _lon = TextEditingController();
  double? _latV, _lonV;
  double _radiusKm = 20 * 1.609344; // 20 miles; the UI is in miles, the maths in km
  MapDetail _detail = MapDetail.streets;

  bool _locating = false, _busy = false, _cancel = false;
  String? _error, _notice;
  ExtractProgress? _progress;

  bool _hasMap = false;
  int _mapBytes = 0;
  String _mapArea = '';
  LatLng? _mapCenter;

  String get _path => StoragePaths.instance.resolve(_item.target);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _cancel = true; // leaving the screen stops a running download and discards the partial file
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final f = File(_path);
    var has = await f.exists();
    var bytes = 0;
    var area = '';
    LatLng? center;
    if (has) {
      bytes = await f.length();
      try {
        final db = sqlite3.open(_path, mode: OpenMode.readOnly);
        try {
          final rows = db.select("SELECT name, value FROM metadata WHERE name IN ('bounds','maxzoom')");
          final m = {for (final r in rows) r['name'] as String: r['value'] as String};
          final b = (m['bounds'] ?? '').split(',').map(double.tryParse).toList();
          if (b.length == 4 && !b.contains(null)) {
            center = LatLng((b[1]! + b[3]!) / 2, (b[0]! + b[2]!) / 2);
            area = '${center.latitude.toStringAsFixed(2)}, ${center.longitude.toStringAsFixed(2)} · up to zoom ${m['maxzoom'] ?? '?'}';
          }
        } finally {
          db.close();
        }
      } catch (_) {
        has = false; // unreadable file: treat as no map
      }
    }
    if (mounted) {
      setState(() {
        _hasMap = has;
        _mapBytes = bytes;
        _mapArea = area;
        _mapCenter = center;
      });
    }
  }

  // ------------------------------------------------------------------ location

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location is turned off. Turn it on in your phone settings, or type coordinates below.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission was declined. You can type coordinates below instead.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 25)));
      _setCoords(pos.latitude, pos.longitude);
    } on TimeoutException {
      _error = 'Could not get a location fix. Try outdoors, or type coordinates below.';
    } catch (e) {
      _error = e is String ? e : 'Could not read your location: $e';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setCoords(double lat, double lon) {
    _latV = lat;
    _lonV = lon;
    _lat.text = lat.toStringAsFixed(4);
    _lon.text = lon.toStringAsFixed(4);
  }

  void _typedCoords() {
    final la = double.tryParse(_lat.text.trim()), lo = double.tryParse(_lon.text.trim());
    setState(() {
      _latV = (la != null && la >= -85 && la <= 85) ? la : null;
      _lonV = (lo != null && lo >= -180 && lo <= 180) ? lo : null;
    });
  }

  MapPlan? get _plan => (_latV == null || _lonV == null) ? null : MapPlan(lat: _latV!, lon: _lonV!, radiusKm: _radiusKm, detail: _detail);

  // ------------------------------------------------------------------ download

  Future<void> _download() async {
    final plan = _plan;
    final source = _category.mapSource;
    if (plan == null || source == null) return;
    final need = (plan.estimatedBytes * 1.4).round();
    final free = await DeviceInfo.freeBytes(StoragePaths.instance.libraryRoot);
    if (free != null && free < need) {
      setState(() => _error = 'Not enough free space: this needs about ${_mb(need)} and ${_mb(free)} is free. Choose a smaller area or less detail.');
      return;
    }
    setState(() {
      _busy = true;
      _cancel = false;
      _error = null;
      _notice = null;
      _progress = null;
    });
    try {
      LoopbackServer.closeMap(_item.id); // release the old file before it is replaced
      final r = await MapDownloader.download(
        source: source,
        plan: plan,
        targetPath: _path,
        isCancelled: () => _cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _notice = 'Downloaded ${r.stats.tiles} tiles (${_mb(r.bytesOnDisk)}) from: ${r.sourceLabel}.';
    } on PmtilesCancelled {
      _notice = 'Download cancelled.';
    } catch (e) {
      _error = e is PmtilesException ? e.message : 'Download failed: $e';
    } finally {
      LoopbackServer.closeMap(_item.id);
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this map?'),
        content: Text('Frees ${_mb(_mapBytes)}. You can download an area again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    LoopbackServer.closeMap(_item.id);
    final f = File(_path);
    if (await f.exists()) await f.delete();
    await _refresh();
  }

  void _open() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AirGapGate(featureName: 'the offline map', child: OfflineMapScreen(item: _item, center: _mapCenter ?? const LatLng(39.0, -77.5), zoom: 10)),
    ));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final sealed = AppSettings.instance.sealed;
    final plan = _plan;
    const heading = TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accent);
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Maps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- current map
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_hasMap ? Icons.map_rounded : Icons.map_outlined, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_hasMap ? 'Map ready · ${_mb(_mapBytes)}' : 'No map downloaded yet', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                ]),
                if (_hasMap && _mapArea.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Centered near $_mapArea', style: const TextStyle(color: AppTheme.muted))),
                if (_hasMap) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: _busy ? null : _open, icon: const Icon(Icons.explore), label: const Text('Open map'))),
                    const SizedBox(width: 10),
                    OutlinedButton(onPressed: _busy ? null : _delete, child: const Text('Delete')),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ---- download
          const Text('Download a map for an area', style: heading),
          const SizedBox(height: 4),
          const Text('Map data is OpenStreetMap. Download once, then use it with no signal.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          if (sealed)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('This node is sealed, so downloads are off. Unseal it in Settings to download a map.', style: TextStyle(color: AppTheme.warn))))
          else ...[
            FilledButton.icon(
              onPressed: (_locating || _busy) ? null : _useMyLocation,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
              label: Text(_locating ? 'Finding you…' : 'Use my location'),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Or type coordinates'),
              initiallyExpanded: _latV != null,
              children: [
                // Headroom: the section clips anything above its first child, which cut off the floating labels.
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: _lat, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude'), onChanged: (_) => _typedCoords())),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _lon, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude'), onChanged: (_) => _typedCoords())),
                ]),
                const SizedBox(height: 8),
              ],
            ),
            if (plan != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Center: ${_latV!.toStringAsFixed(4)}, ${_lonV!.toStringAsFixed(4)}\n${_coverage(_latV!, _lonV!)}', style: const TextStyle(color: AppTheme.muted, height: 1.4))),
            const SizedBox(height: 8),
            const Text('How far around', style: heading),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final mi in const [10.0, 20.0, 40.0, 60.0])
                ChoiceChip(
                    label: Text('${mi.round()} miles'),
                    selected: (_radiusKm - mi * 1.609344).abs() < 0.01,
                    onSelected: _busy ? null : (_) => setState(() => _radiusKm = mi * 1.609344)),
            ]),
            const SizedBox(height: 14),
            const Text('Detail', style: heading),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final d in MapDetail.values) ChoiceChip(label: Text(d.label), selected: _detail == d, onSelected: _busy ? null : (_) => setState(() => _detail = d)),
            ]),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_detail.blurb, style: const TextStyle(color: AppTheme.muted, fontSize: 13))),
            const SizedBox(height: 16),
            if (plan != null) _estimate(plan),
            const SizedBox(height: 12),
            if (_busy) ...[
              LinearProgressIndicator(value: (_progress != null && _progress!.total > 0) ? _progress!.done / _progress!.total : null, minHeight: 8, borderRadius: BorderRadius.circular(4), backgroundColor: AppTheme.accentSoft),
              const SizedBox(height: 8),
              Text(_progress == null ? 'Starting…' : '${_progress!.phase}${_progress!.total > 0 ? ' ${_progress!.done}/${_progress!.total}' : ''}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => setState(() => _cancel = true), child: const Text('Cancel')),
            ] else
              FilledButton.icon(
                onPressed: plan == null ? null : _download,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.download),
                label: Text(_hasMap ? 'Replace map with this area' : 'Download map'),
              ),
          ],
          if (_notice != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_notice!, style: const TextStyle(color: AppTheme.ok))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
          const SizedBox(height: 24),
          const Text('Map data © OpenStreetMap contributors (ODbL) and Natural Earth, from the Protomaps basemap.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ],
      ),
    );
  }

  /// Tells the user where the map will come from for this spot.
  String _coverage(double lat, double lon) {
    final regions = _category.mapSource?.regionsFor(lat, lon) ?? const <MapRegion>[];
    return regions.isNotEmpty ? 'Covered by our hosted map: ${regions.first.name}' : 'Outside our hosted maps: will use the public world map instead';
  }

  Widget _estimate(MapPlan plan) {
    final tiles = plan.selection.tileCount;
    final size = plan.estimatedBytes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card, border: Border.all(color: AppTheme.outline), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.storage_outlined, color: AppTheme.accent),
        const SizedBox(width: 12),
        Expanded(child: Text('About ${_mb(size)} · $tiles map tiles\nDense cities can be larger.', style: const TextStyle(height: 1.4))),
      ]),
    );
  }
}
