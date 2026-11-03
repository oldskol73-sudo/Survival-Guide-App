# Survival Node Mobile

An offline-first technical library for iOS and Android, built with Flutter. Read `ARCHITECTURE.md` first.

## What was verified, and what was not

| Part | Status |
|---|---|
| `native/llama_shim` | Compiled and linked against llama.cpp `master` (Nov 2026, commit 9309bf1) on Linux x86-64. Error paths smoke-tested through the C ABI. The UTF-8 streaming boundary logic was unit-tested. **Not yet run with a real GGUF model.** |
| `native/zim_shim` | Syntax-checked against current libzim headers. Not linked: libzim must be cross-built for mobile. |
| SQL (FTS5 schema, upsert, search, snippet/BM25, delete, stats) | Extracted from the Dart source and executed against SQLite FTS5 |
| sqlite-vec SQL (`vec0` cosine, KNN, delete + insert, backfill) | Executed against a locally built sqlite-vec. Results match brute-force cosine. |
| FTS query sanitiser | 14 cases checked against FTS5; the same cases are in `test/fts_query_test.dart` |
| Dart / Flutter code | Written against the current source of every package listed in `pubspec.yaml`. **No Flutter SDK was available, so it has not been compiled.** Run `flutter analyze` first and expect small fixes. |
| Catalog URLs | Live public links when written. `sha256` is `null` (trust-on-first-use) until you pin hashes from a verified copy. |

## Build

```bash
flutter create --org org.survivalnode --project-name survival_node_mobile --platforms ios,android .
# keep the files from this repo when asked; then merge:
#   android/app/build.gradle.kts.native-snippet  -> android/app/build.gradle.kts
#   ios/Info.plist.additions.xml                 -> ios/Runner/Info.plist

# Native sources
git submodule add https://github.com/ggml-org/llama.cpp native/third_party/llama.cpp
git submodule add https://github.com/asg017/sqlite-vec  native/third_party/sqlite-vec
(cd native/third_party/sqlite-vec && make sqlite-vec.h)
# sqlite3.h + sqlite3ext.h from the SQLite amalgamation -> native/third_party/sqlite-headers/

# libzim for the ZIM reader (optional; the app hides ZIM if it is absent)
git clone https://github.com/kiwix/kiwix-build && cd kiwix-build
kiwix-build --target-platform android_arm64 libzim   # copy include/ + lib/ to native/third_party/libzim/arm64-v8a/

flutter pub get
flutter test
flutter run --release
```

### iOS native code

There is no `.so` loading on iOS. Every symbol must be inside the app binary, and Dart reaches it through `DynamicLibrary.process()`.

1. Build llama.cpp as an XCFramework with Metal: `./build-xcframework.sh` in the llama.cpp repo. Add `llama.xcframework` to the Runner target.
2. Add `native/llama_shim/sn_llama.cpp` and `native/third_party/sqlite-vec/sqlite-vec.c` to Runner → Build Phases → Compile Sources. For `sqlite-vec.c`, set the compiler flag `-DSQLITE_VEC_OMIT_FS=1`.
3. Optional ZIM: build libzim with `kiwix-build --target-platform iOS_arm64 libzim`, link the static libraries and add `native/zim_shim/sn_zim.cpp`.
4. Build Settings → *Dead Code Stripping* stays on. The `__attribute__((used))` markers keep the `sn_*` symbols.

## First run (Stage A)

1. Library tab: choose categories, then tap **Sync selected categories**.
2. Wait for every item to show **Verified** or **Ready · hash recorded**. PDFs are indexed automatically, and the AI embeds them in the background.
3. Download the models in the *On-device AI models* category: the embedder plus one GGUF.
4. Settings → **Seal node**. Then turn on Airplane Mode and check the banner turns green.

## Licences of bundled content

The US Government manuals are public domain. Wikipedia ZIMs are CC BY-SA, and OpenStreetMap data is ODbL (attribution is shown on the map). Llama 3.2 is under the Llama 3.2 Community License, and Qwen2.5 and MiniLM are under Apache-2.0. Check each licence before you redistribute a pre-loaded build.
