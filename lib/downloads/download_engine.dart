// Stage A download engine.
//
// * Native background queues (iOS URLSession / Android WorkManager) via background_downloader: tasks keep
//   running while the app is suspended and are rehydrated after process death (FileDownloader().start()).
// * Concurrency: holding queue = 3 transfers total, 2 per host.
// * 64 MB to 4 GB files use ParallelDownloadTask (4 HTTP Range chunks, mirrors as extra sources).
//   Larger files (100 GB ZIMs) use a plain pausable DownloadTask, because parallel tasks cannot resume.
// * Every completed file is SHA-256 verified on a background isolate before it is usable.
// * Disk guard: pre-flight space check + periodic check that pauses everything below a floor.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../catalog/catalog_models.dart';
import '../core/device_info.dart';
import '../core/storage_paths.dart';
import 'checksum.dart';

enum JobStatus {
  idle,
  queued,
  waitingForNetwork,
  downloading,
  paused,
  verifying,
  verified, // hash matched a pinned or sidecar hash
  unverified, // no expected hash: trust on first use, hash recorded
  corrupt,
  failed,
  insufficientSpace,
}

class JobState {
  JobState(this.id);
  final String id;
  JobStatus status = JobStatus.idle;
  double progress = 0;
  int totalBytes = -1;
  String? sha256;
  String? error;
  int verifyAttempts = 0;
  int mirrorIndex = 0;
  bool pausedForLowDisk = false;

  bool get isUsable => status == JobStatus.verified || status == JobStatus.unverified;

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.name,
        'progress': progress,
        'totalBytes': totalBytes,
        'sha256': sha256,
        'error': error,
        'verifyAttempts': verifyAttempts,
        'mirrorIndex': mirrorIndex,
      };

  factory JobState.fromJson(Map<String, dynamic> j) => JobState(j['id'] as String)
    ..status = JobStatus.values.asNameMap()[j['status']] ?? JobStatus.idle
    ..progress = (j['progress'] as num?)?.toDouble() ?? 0
    ..totalBytes = j['totalBytes'] as int? ?? -1
    ..sha256 = j['sha256'] as String?
    ..error = j['error'] as String?
    ..verifyAttempts = j['verifyAttempts'] as int? ?? 0
    ..mirrorIndex = j['mirrorIndex'] as int? ?? 0;
}

enum EnqueueResult { enqueued, alreadyUsable, placeholder, insufficientSpace, rejected }

class DownloadEngine extends ChangeNotifier {
  DownloadEngine._();
  static final DownloadEngine instance = DownloadEngine._();

  static const _group = 'library';
  static const _mb = 1024 * 1024;
  static const _headroomBytes = 500 * _mb;
  static const _pauseFloorBytes = 300 * _mb;
  static const _parallelMin = 64 * _mb;
  static const _parallelMax = 4096 * _mb;

  late Catalog _catalog;
  late StoragePaths _paths;
  final Map<String, JobState> jobs = {};
  final ValueNotifier<bool> lowDisk = ValueNotifier(false);
  final _verifiedCtl = StreamController<CatalogItem>.broadcast();
  StreamSubscription<TaskUpdate>? _sub;
  Timer? _diskTimer;
  Timer? _saveDebounce;

  /// Emits each item once its file is verified (or TOFU-recorded). The indexer subscribes to this.
  Stream<CatalogItem> get onVerified => _verifiedCtl.stream;

  File get _jobsFile => File(p.join(_paths.stateDir, 'jobs.json'));

  Future<void> init(Catalog catalog, StoragePaths paths) async {
    _catalog = catalog;
    _paths = paths;
    await _loadJobs();

    await FileDownloader().configure(globalConfig: [
      (Config.holdingQueue, (3, 2, null)),
      (Config.excludeFromCloudBackup, Config.always), // a 100 GB library must not go to iCloud
    ]);
    // Android: WorkManager caps ordinary tasks at ~9 minutes. allowPause:true already resumes across
    // those cycles; foreground mode for files > 200 MB additionally keeps the transfer alive and visible.
    await FileDownloader().configure(androidConfig: [(Config.runInForegroundIfFileLargerThan, 200)]);
    FileDownloader().configureNotification(
      running: const TaskNotification('Blackout IQ', 'Downloading {displayName}'),
      complete: const TaskNotification('Blackout IQ', '{displayName} downloaded, verifying'),
      error: const TaskNotification('Blackout IQ', '{displayName} failed'),
      paused: const TaskNotification('Blackout IQ', '{displayName} paused'),
      progressBar: true,
    );

    _sub = FileDownloader().updates.listen(_onUpdate);
    // Tracks tasks in the downloader DB, re-emits updates that happened while suspended, and
    // reschedules tasks the OS killed.
    await FileDownloader().start();
    await _reconcileAfterRestart();

    _diskTimer = Timer.periodic(const Duration(seconds: 30), (_) => _diskGuard());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _diskTimer?.cancel();
    _verifiedCtl.close();
    super.dispose();
  }

  JobState jobFor(String id) => jobs.putIfAbsent(id, () => JobState(id));

  // ---------------------------------------------------------------- enqueue

  Future<EnqueueResult> enqueue(CatalogItem item, {int mirrorIndex = 0}) async {
    if (item.isPlaceholder) return EnqueueResult.placeholder;
    final job = jobFor(item.id);
    if (job.isUsable && await File(_paths.resolve(item.target)).exists()) return EnqueueResult.alreadyUsable;

    final urls = [item.url, ...item.mirrors].map((u) => u.toString()).toList();
    if (mirrorIndex >= urls.length) return EnqueueResult.rejected;
    final (base, dir, filename) = _location(item);
    await Directory(p.dirname(_paths.resolve(item.target))).create(recursive: true);

    // Size: catalog value, else a HEAD probe (fails offline: then we enqueue and let the OS wait).
    var size = item.sizeBytes ?? -1;
    if (size <= 0) {
      try {
        size = await DownloadTask(url: urls[mirrorIndex], filename: filename, directory: dir, baseDirectory: base)
            .expectedFileSize()
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        size = -1;
      }
    }

    if (size > 0) {
      final free = await DeviceInfo.freeBytes(p.dirname(_paths.resolve(item.target)));
      if (free != null && free < size * 1.10 + _headroomBytes) {
        job
          ..status = JobStatus.insufficientSpace
          ..totalBytes = size
          ..error = 'Needs ${_fmt(size * 1.10 + _headroomBytes)}, ${_fmt(free.toDouble())} free';
        _changed();
        return EnqueueResult.insufficientSpace;
      }
    }

    final meta = jsonEncode({'mirror': mirrorIndex});
    final Task task = (size >= _parallelMin && size <= _parallelMax)
        ? ParallelDownloadTask(
            taskId: item.id,
            url: urls.sublist(mirrorIndex), // mirrors become extra chunk sources
            chunks: 4,
            filename: filename,
            directory: dir,
            baseDirectory: base,
            group: _group,
            updates: Updates.statusAndProgress,
            retries: 3,
            metaData: meta,
            displayName: item.title,
          )
        : DownloadTask(
            taskId: item.id,
            url: urls[mirrorIndex],
            filename: filename,
            directory: dir,
            baseDirectory: base,
            group: _group,
            updates: Updates.statusAndProgress,
            retries: 3,
            allowPause: true, // resume with HTTP Range after network loss or suspension
            metaData: meta,
            displayName: item.title,
          );

    final ok = await FileDownloader().enqueue(task);
    if (!ok) {
      job
        ..status = JobStatus.failed
        ..error = 'Could not enqueue';
      _changed();
      return EnqueueResult.rejected;
    }
    job
      ..mirrorIndex = mirrorIndex
      ..totalBytes = size
      ..error = null
      ..status = await _online() ? JobStatus.queued : JobStatus.waitingForNetwork;
    _changed();
    return EnqueueResult.enqueued;
  }

  Future<void> enqueueCategories(Set<String> categoryIds) async {
    for (final c in _catalog.categories.where((c) => categoryIds.contains(c.id))) {
      for (final item in c.items) {
        await enqueue(item);
      }
    }
  }

  Future<void> cancel(String id) async {
    await FileDownloader().cancelTaskWithId(id);
    jobFor(id).status = JobStatus.idle;
    _changed();
  }

  /// Location in background_downloader terms. iOS container paths change on every app update, so on
  /// iOS we always use a base directory + relative path. Android paths (including microSD) are stable.
  (BaseDirectory, String, String) _location(CatalogItem item) {
    final abs = _paths.resolve(item.target);
    final filename = p.basename(abs);
    final parent = p.dirname(abs);
    if (item.isPrivateModel) {
      return (BaseDirectory.applicationSupport, p.relative(parent, from: _paths.appSupport), filename);
    }
    if (Platform.isIOS) {
      return (BaseDirectory.applicationDocuments, p.relative(parent, from: _paths.volume.root), filename);
    }
    return (BaseDirectory.root, parent, filename);
  }

  // ---------------------------------------------------------------- updates

  void _onUpdate(TaskUpdate update) {
    final item = _catalog.itemById(update.task.taskId);
    if (item == null) return;
    final job = jobFor(item.id);

    switch (update) {
      case TaskStatusUpdate(:final status, :final exception):
        switch (status) {
          case TaskStatus.enqueued:
            job.status = JobStatus.queued;
          case TaskStatus.running:
            job
              ..status = JobStatus.downloading
              ..pausedForLowDisk = false;
          case TaskStatus.paused:
            job.status = JobStatus.paused;
          case TaskStatus.waitingToRetry:
            job.status = JobStatus.waitingForNetwork;
          case TaskStatus.complete:
            unawaited(_verify(item));
          case TaskStatus.notFound:
          case TaskStatus.failed:
            final next = job.mirrorIndex + 1;
            final isParallel = update.task is ParallelDownloadTask; // already used every mirror
            if (!isParallel && next <= item.mirrors.length) {
              unawaited(enqueue(item, mirrorIndex: next));
            } else {
              job
                ..status = JobStatus.failed
                ..error = exception?.description ?? status.name;
            }
          case TaskStatus.canceled:
            job.status = job.pausedForLowDisk ? JobStatus.paused : JobStatus.idle;
        }
      case TaskProgressUpdate(:final progress, :final expectedFileSize):
        // Negative progress values are status sentinels, not percentages.
        if (progress >= 0 && progress <= 1) job.progress = progress;
        if (expectedFileSize > 0) job.totalBytes = expectedFileSize;
    }
    _changed();
  }

  // ---------------------------------------------------------------- verification

  Future<void> _verify(CatalogItem item) async {
    final job = jobFor(item.id)..status = JobStatus.verifying;
    _changed();
    final path = _paths.resolve(item.target);
    try {
      if (!await File(path).exists()) throw const FileSystemException('file missing after download');
      final expected = item.sha256 ?? await _fetchSidecar(item);
      final actual = await sha256OfFile(path);
      if (expected == null) {
        job
          ..status = JobStatus.unverified
          ..sha256 = actual;
      } else if (hashesEqual(expected, actual)) {
        job
          ..status = JobStatus.verified
          ..sha256 = actual;
      } else {
        await _quarantine(path);
        job.verifyAttempts++;
        if (job.verifyAttempts < 2) {
          job.error = 'Checksum mismatch, retrying once';
          _changed();
          await enqueue(item, mirrorIndex: job.mirrorIndex);
          return;
        }
        job
          ..status = JobStatus.corrupt
          ..error = 'Checksum mismatch (expected ${expected.substring(0, 12)}..., got ${actual.substring(0, 12)}...)';
      }
    } catch (e) {
      job
        ..status = JobStatus.failed
        ..error = 'Verification error: $e';
    }
    _changed();
    if (job.isUsable && item.index) _verifiedCtl.add(item);
  }

  /// Re-hash before opening, so a file altered through Files/USB is caught.
  Future<bool> verifyBeforeOpen(CatalogItem item) async {
    final job = jobs[item.id];
    if (job?.sha256 == null) return false;
    try {
      return hashesEqual(job!.sha256!, await sha256OfFile(_paths.resolve(item.target)));
    } catch (_) {
      return false;
    }
  }

  Future<String?> _fetchSidecar(CatalogItem item) async {
    final u = item.sha256Url;
    if (u == null) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(u);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return parseSha256Sidecar(body);
    } catch (_) {
      return null; // offline or sealed: falls back to trust-on-first-use
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _quarantine(String path) async {
    final dest = p.join(_paths.quarantineDir, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}');
    try {
      await File(path).rename(dest);
    } on FileSystemException {
      // Cross-volume (microSD to internal) rename fails: delete instead, never keep a bad file in place.
      await File(path).delete().catchError((_) => File(path));
    }
  }

  // ---------------------------------------------------------------- resilience

  Future<void> _reconcileAfterRestart() async {
    final live = {for (final t in await FileDownloader().allTasks(group: _group)) t.taskId};
    for (final item in _catalog.allItems) {
      final job = jobs[item.id];
      if (job == null) continue;
      final inFlight = {JobStatus.queued, JobStatus.downloading, JobStatus.paused, JobStatus.waitingForNetwork, JobStatus.verifying};
      if (!inFlight.contains(job.status) || live.contains(item.id)) continue;
      // The native queue no longer knows this task: either it finished while we were dead,
      // or it was lost. A file on disk gets verified; otherwise the job is re-enqueued.
      if (await File(_paths.resolve(item.target)).exists()) {
        unawaited(_verify(item));
      } else {
        unawaited(enqueue(item, mirrorIndex: job.mirrorIndex));
      }
    }
  }

  Future<void> _diskGuard() async {
    if (!jobs.values.any((j) => j.status == JobStatus.downloading)) return;
    final free = await DeviceInfo.freeBytes(_paths.libraryRoot);
    if (free == null) return;
    final low = free < _pauseFloorBytes;
    if (low && !lowDisk.value) {
      final paused = await FileDownloader().pauseAll(group: _group);
      final pausedIds = {for (final t in paused) t.taskId};
      // Parallel tasks cannot pause: cancel them; they restart from zero once space is freed.
      for (final j in jobs.values.where((j) => j.status == JobStatus.downloading)) {
        j.pausedForLowDisk = true;
        if (!pausedIds.contains(j.id)) await FileDownloader().cancelTaskWithId(j.id);
      }
    }
    lowDisk.value = low;
  }

  /// Call after the user frees space.
  Future<void> resumeAfterLowDisk() async {
    lowDisk.value = false;
    await FileDownloader().resumeAll(group: _group);
    for (final j in jobs.values.where((j) => j.pausedForLowDisk && j.status != JobStatus.downloading)) {
      final item = _catalog.itemById(j.id);
      if (item != null) await enqueue(item, mirrorIndex: j.mirrorIndex);
    }
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none && c != ConnectivityResult.bluetooth);
  }

  // ---------------------------------------------------------------- persistence

  Future<void> _loadJobs() async {
    try {
      final list = jsonDecode(await _jobsFile.readAsString()) as List;
      for (final j in list) {
        final s = JobState.fromJson(j as Map<String, dynamic>);
        jobs[s.id] = s;
      }
    } catch (_) {
      // first run
    }
  }

  void _changed() {
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final tmp = File('${_jobsFile.path}.tmp');
      await tmp.writeAsString(jsonEncode([for (final j in jobs.values) j.toJson()]), flush: true);
      await tmp.rename(_jobsFile.path);
    });
  }

  static String _fmt(double bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes;
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(1)} ${units[i]}';
  }
}
