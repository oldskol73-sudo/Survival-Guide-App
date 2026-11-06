// Bootstrap order matters:
//   1. paths + settings  2. lockdown (if sealed) before ANY network-capable code runs
//   3. sqlite-vec registration before the DB opens  4. index + downloads  5. AI workers  6. monitor + server

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'airgap/airgap_monitor.dart';
import 'airgap/network_lockdown.dart';
import 'catalog/catalog_models.dart';
import 'catalog/local_library.dart';
import 'core/services.dart';
import 'core/settings.dart';
import 'core/storage_paths.dart';
import 'core/theme.dart';
import 'family/family_store.dart';
import 'home/checklist_store.dart';
import 'vault/vault_store.dart';
import 'downloads/download_engine.dart';
import 'rag/vector_store.dart';
import 'search/fts_index.dart';
import 'ui/screens.dart';
import 'viewers/loopback_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final catalog = Catalog.parse(await rootBundle.loadString('assets/catalog/categories.json'));
  Services.catalog = catalog;

  var paths = await StoragePaths.init();
  final settings = await AppSettings.load(paths.stateDir, catalog.categories.where((c) => c.defaultEnabled).map((c) => c.id));
  if (settings.volumeIndex != 0) paths = await StoragePaths.init(volumeIndex: settings.volumeIndex);
  await ChecklistStore.load(paths.stateDir);
  await FamilyStore.load(paths.stateDir);
  await VaultStore.init(paths.stateDir);

  if (settings.sealed) NetworkLockdown.engage();

  final vecRegistered = VectorStore.registerSqliteVec();
  Services.fts = FtsIndex.open(paths.dbFile);
  Services.vectors = VectorStore.attach(Services.fts, extensionRegistered: vecRegistered);

  final engine = DownloadEngine.instance;
  await engine.init(catalog, paths);
  engine.onVerified.listen(_onItemVerified);
  // Index anything verified earlier but not indexed (e.g. app killed during indexing).
  for (final item in catalog.allItems.where((i) => i.index && (engine.jobs[i.id]?.isUsable ?? false))) {
    unawaited(Services.fts.indexItem(item, sha256: engine.jobs[item.id]!.sha256!));
  }

  unawaited(LocalLibrary.scanAndIndex(catalog, paths)); // PDFs placed in the library folder by hand or by cable

  await Services.refreshTier();
  await Services.ensureEmbedder();
  unawaited(Services.scheduler?.run());

  await AirGapMonitor.instance.start();
  await LoopbackServer.start(catalog);

  runApp(const SurvivalNodeApp());
}

Future<void> _onItemVerified(CatalogItem item) async {
  final job = DownloadEngine.instance.jobs[item.id];
  if (item.kind == CategoryKind.model) {
    await Services.ensureEmbedder(); // the ONNX model or vocab may have just arrived
    unawaited(Services.scheduler?.run());
    return;
  }
  if (item.kind == CategoryKind.pdf && job?.sha256 != null) {
    await Services.fts.indexItem(item, sha256: job!.sha256!);
    unawaited(Services.scheduler?.run());
  }
}

class SurvivalNodeApp extends StatefulWidget {
  const SurvivalNodeApp({super.key});

  @override
  State<SurvivalNodeApp> createState() => _SurvivalNodeAppState();
}

class _SurvivalNodeAppState extends State<SurvivalNodeApp> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onPause: AirGapMonitor.instance.pause, // no polling while backgrounded
      onResume: AirGapMonitor.instance.resume,
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Blackout IQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.build(),
        home: const HomeShell(),
      );
}
