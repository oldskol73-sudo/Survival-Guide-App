# Survival Node Mobile — Architecture Specification

Flutter (Dart 3.10+, Flutter 3.38+) · iOS 15+ · Android 8.0+ (API 26), arm64 only

Survival Node Mobile is an offline-first technical library. It runs in two states:

* **Stage A, Online Preparation.** The app downloads, verifies and indexes manuals, ZIM archives and map tiles.
* **Stage B, Air-Gap.** The radios are off and the app refuses every non-loopback socket. Search, reading, maps and AI Q&A run entirely on the device.

---

## 1. System architecture

```
┌──────────────────────────────────────────── Flutter UI (OLED #000000 theme) ───────────────────────────────────────────┐
│  LibraryScreen   SearchScreen   AskScreen (streaming)   ReaderScreen (PDF)   ZimScreen (WebView)   MapScreen (MapLibre) │
│        └──────────────┴───────────── AirGapGate / AirGapBanner (wraps every Stage-B screen) ─────────────┘             │
└────────────┬───────────────────┬───────────────────────┬────────────────────────┬───────────────────────┬─────────────┘
             │                   │                       │                        │                       │
   ┌─────────▼────────┐ ┌────────▼─────────┐ ┌───────────▼────────────┐ ┌─────────▼─────────┐ ┌───────────▼──────────┐
   │ DownloadEngine   │ │ FtsIndex         │ │ RagPipeline            │ │ LoopbackServer    │ │ AirGapMonitor        │
   │ background_      │ │ SQLite FTS5      │ │  Embedder (ONNX, 384d) │ │ 127.0.0.1:random  │ │ connectivity_plus    │
   │ downloader +     │ │ pdfrx (PDFium)   │ │  VectorStore           │ │  /zim/* → libzim  │ │ flutter_blue_plus    │
   │ SHA-256 isolate  │ │ text extraction  │ │   sqlite-vec | brute   │ │  /tiles/* → MBTiles│ │ native: airplane,    │
   │ disk-space guard │ │ query sanitiser  │ │  LlmWorker isolate     │ │  /style.json      │ │ wifi-radio, BT       │
   └─────────┬────────┘ └────────┬─────────┘ └───────────┬────────────┘ └─────────┬─────────┘ │ NetworkLockdown      │
             │                   │                       │                        │           │ (HttpOverrides)      │
             │                   │            ┌──────────▼───────────┐            │           └──────────────────────┘
             │                   │            │ dart:ffi             │            │
             │                   │            │ libsn_llama.so/.a    │  libsn_zim (C shim over libzim C++)
             │                   │            │ (C shim → llama.cpp) │            │
             ▼                   ▼            └──────────────────────┘            ▼
   ┌──────────────────────────────────────── App sandbox / external storage ──────────────────────────────────────────┐
   │ library/ (PDF, ZIM, MBTiles)   db/library.db (FTS5 + chunks + vec0)   models/ (GGUF, ONNX)   state/ (JSON)        │
   └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                  DeviceInfoChannel (Kotlin / Swift): free disk, total RAM, radio state
```

### State machine

```
            ┌───────────────┐  user taps "Seal node"   ┌──────────────────┐
  launch ──►│ STAGE A       │ ───────────────────────► │ STAGE B (sealed) │
            │ online prep   │   requires: all jobs     │ NetworkLockdown  │
            │ downloads OK  │   verified + indexed     │ ON; radios must  │
            └───────▲───────┘                          │ be off to open   │
                    │  user taps "Unseal" + confirms   │ gated screens    │
                    └──────────────────────────────────┴──────────────────┘
```

* **Sealing** installs `NetworkLockdown`, a process-wide `HttpOverrides`. After that, any `HttpClient` connection to a host other than `127.0.0.1` / `::1` throws `AirGapViolation`. This catches packages that try to phone home.
* **Gated screens** (Ask, Reader, ZIM, Map) are wrapped in `AirGapGate`. If any radio is detected on, the gate shows a full-screen warning with an explicit "Proceed anyway" override. It never silently blocks the user.

---

## 2. Storage layout and sandbox separation

```
<AppSupport>/                         iOS: Library/Application Support (excluded from iCloud backup)
│                                     Android: /data/data/<pkg>/files   (private, never world-readable)
├── db/
│   └── library.db                    FTS5 pages, chunks, embeddings (vec0 or BLOB), document registry
├── models/
│   ├── embed/all-MiniLM-L6-v2.onnx   384-d sentence embedder (~90 MB fp32 / ~23 MB int8)
│   ├── embed/vocab.txt               WordPiece vocabulary
│   └── llm/<model>.gguf              Llama-3.2-1B-Instruct or Qwen2.5-1.5B-Instruct, Q4_K_M
├── state/
│   ├── catalog.json                  active catalog (bundled asset copied on first run)
│   ├── jobs.json                     per-file verification + index state
│   └── settings.json                 low-power mode, sealed flag, storage volume choice
└── tmp/                              *.part downloads; cleaned at startup

<Documents>/SurvivalNode/             iOS: visible in the Files app (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace)
                                      Android: app-specific external dir on the chosen volume (see below)
└── library/
    ├── 01_Water_Sanitation/…pdf
    ├── 02_Mechanical_Electrical/…pdf
    ├── … 03–09 …
    ├── 10_Kiwix_ZIM/*.zim
    └── 11_Maps/*.mbtiles  (+ *.obf for OsmAnd hand-off)

Android volumes (no storage permission required: scoped storage, app-specific dirs):
  internal  /storage/emulated/0/Android/data/<pkg>/files/SurvivalNode/library
  microSD   /storage/XXXX-XXXX/Android/data/<pkg>/files/SurvivalNode/library   ← getExternalStorageDirectories()[1]
```

**Separation rules**

* Executable or trusted state (models, the database, settings) lives only in the private `AppSupport` sandbox.
* User-visible content (the library) is reference data. The database stores each file's SHA-256 and re-verifies it on open (`verifyOnOpen` setting), so a file edited through the Files app is detected.
* Android 11+ hides `Android/data` from most file managers. To make a manual visible system-wide, *Export* copies it to `Downloads/SurvivalNode` through MediaStore (`FileDownloader().moveToSharedStorage`).
* App-specific external directories are deleted on uninstall. Warn the user before uninstalling, or export first.

---

## 3. Key design decisions

| Concern | Choice | Reason |
|---|---|---|
| Framework | Flutter | `dart:ffi` gives direct, zero-copy C calls into llama.cpp, libzim and sqlite-vec. `background_downloader` gives native URLSession / WorkManager queues. |
| Downloads | `background_downloader` 9.x, holding queue (3 concurrent, 2 per host). Files of 64 MB to 4 GB use `ParallelDownloadTask` (4 Range chunks, mirrors as extra sources). Bigger files use a pausable single task, because parallel tasks cannot resume | Survives app suspension and process death; resumes with HTTP Range requests |
| Integrity | Streaming SHA-256 in an isolate (64 KB chunks) | Constant memory for 100 GB ZIMs; UI stays at 60 fps |
| PDF | `pdfrx` (PDFium, both platforms) | One native engine for rendering and text extraction |
| Full-text search | SQLite FTS5, `porter unicode61` tokenizer, BM25 with a title boost, `snippet()` | FTS5 queries are typically a few milliseconds on tens of thousands of pages, well inside the 100 ms target. Boolean + prefix syntax |
| Vectors | `sqlite-vec` `vec0` with cosine metric; automatic fallback to brute-force cosine over Float32 BLOBs | Works even if the extension fails to load |
| Embeddings | ONNX Runtime Mobile, all-MiniLM-L6-v2 (384-d), Dart WordPiece tokenizer, mean pooling + L2 normalisation | Small, CPU-only, well-understood |
| LLM | llama.cpp through a 9-function C shim (`sn_llama.h`), run on a dedicated worker isolate | Shields Dart from llama.cpp API churn; cancellable; streaming |
| ZIM | libzim through a C shim, served at `http://127.0.0.1:<port>/zim/<book>/<path>` to a WebView | ZIM HTML uses relative links; a loopback origin resolves them exactly |
| Maps | MapLibre GL rendering vector MBTiles served by the same loopback server | MapLibre cannot read OsmAnd `.obf`. `.obf` files are handed to OsmAnd through a share intent (Android) |
| Encryption (optional) | `sqlite3` hook `source: sqlcipher` | Encrypts the index if the device is seized |

---

## 4. Memory and degradation tiers

`ModelTier.select()` reads total RAM from the native channel at startup:

| Total RAM | LLM | Context | Threads | Behaviour |
|---|---|---|---|---|
| ≥ 8 GB | Qwen2.5-1.5B-Instruct Q4_K_M (~1.1 GB) | 4096 | min(6, cores−2) | Full RAG |
| 6–8 GB | Llama-3.2-1B-Instruct Q4_K_M (~0.8 GB) | 4096 | 4 | Full RAG |
| 4–6 GB | Llama-3.2-1B-Instruct Q4_K_M | 2048 | 3 | Full RAG, top-3 chunks trimmed to fit |
| < 4 GB | none | n/a | n/a | **Retrieval-only**: show the top passages with citations, no generation |

On `didHaveMemoryPressure` (iOS memory warning / Android `onTrimMemory`), the LLM worker unloads the model and the UI drops to retrieval-only until the next query. **Low-power mode** halves threads, caps output at 256 tokens, pauses background embedding, and disables map hill-shading.

---

## 5. Edge cases handled

| Situation | Handling |
|---|---|
| No network at all (Stage A) | Downloads stay `enqueued`; banner says "Waiting for network"; nothing is marked failed |
| App suspended / killed mid-download | Native queue keeps running (iOS background URLSession, Android WorkManager). `FileDownloader().start()` on launch rehydrates tasks and reschedules killed ones |
| Server ignores Range | `background_downloader` restarts from zero; the hash check still guards the result |
| Checksum mismatch | File quarantined to `tmp/quarantine/`, job marked `corrupt`, one automatic re-download, then manual |
| Hash unknown in catalog (`sha256: null`) | Computed hash is recorded as *trust-on-first-use* and shown as "unverified" in the UI |
| Low disk | Pre-flight: free space must be ≥ size × 1.10 + 500 MB headroom, or the job is refused. Re-checked every 30 s while downloading; pauses all tasks below 300 MB |
| Scanned PDFs with no text layer | Page indexed with an empty body. Document flagged `needsOcr` so the UI can say it is not searchable |
| Corrupt or encrypted PDF | Indexing skips it, records the error, and continues with the next file |
| Malformed FTS query (e.g. `"water`) | Sanitiser balances quotes and parentheses, drops stray operators, and moves a leading `-term` / `NOT term` to the end. On `SqliteException`, the query is retried as a quoted phrase |
| sqlite-vec missing | Brute-force cosine fallback (~40 ms for 20k chunks on a mid-range phone) |
| Prompt exceeds context | Chunks trimmed from the lowest-ranked one until prompt + 512 response tokens fit |
| User cancels generation | Atomic cancel flag checked between tokens in C; the worker stays loaded |

---

## 6. Platform truths (read before shipping)

* **No app can turn airplane mode on.** Android removed that ability for third-party apps in 4.2 and iOS never had it. The app detects and warns; the user flips the switch.
* **iOS cannot read radio power state.** iOS exposes only "is there a usable path" (`NWPathMonitor`) and Bluetooth state through CoreBluetooth. An enabled-but-unconnected Wi-Fi radio looks like "none" on iOS. The banner says so on iOS and asks the user to confirm Airplane Mode in Control Center.
* **Any app on the phone can connect to a loopback port.** The loopback server therefore requires a random per-launch token in every URL.
* **Android needs `INTERNET` permission even for loopback sockets.** The ZIM and map viewers depend on 127.0.0.1, so the permission stays; `NetworkLockdown` enforces the air gap at app level instead.
* **GPS is receive-only.** It does not break the air gap and stays usable in airplane mode for the map's location dot.
* **Building libzim for mobile is the heaviest step.** It depends on Xapian, zstd, xz/lzma and ICU. Kiwix maintains cross-compilation scripts in `kiwix/kiwix-build` (targets `android_arm64`, `iOS_arm64`). Use those, then link `native/zim_shim`.

---

## 7. Source map

```
pubspec.yaml
assets/catalog/categories.json          Category configuration data model (deliverable 2)
lib/main.dart                           Bootstrap, OLED theme, routing
lib/core/…                              theme, settings, storage paths, device-info channel, model tier, service registry
lib/catalog/catalog_models.dart         Typed model + validation for categories.json
lib/downloads/…                         Download engine + SHA-256 verifier + disk guard (deliverable 3)
lib/search/…                            PDF text extraction, FTS5 index, query sanitiser (deliverable 4)
lib/rag/…                               Tokenizer, embedder, chunker, vector store, llama FFI, worker, pipeline, RagController/RagBuilder hook (deliverable 5)
lib/airgap/…                            Monitor, banner, gate, lockdown (deliverable 6)
lib/viewers/…                           Loopback server, ZIM FFI, map, PDF reader
lib/ui/screens.dart                     Library, Search, Ask, Settings
test/fts_query_test.dart                Query-sanitiser unit tests
native/llama_shim/                      C shim + CMake for llama.cpp
native/zim_shim/                        C shim over libzim
native/sqlite_vec/                      CMake to build sqlite-vec as a loadable library
android/…                               Kotlin DeviceInfo channel, manifest, Gradle CMake hook
ios/…                                   Swift DeviceInfo channel, Info.plist keys, podspec notes
```
