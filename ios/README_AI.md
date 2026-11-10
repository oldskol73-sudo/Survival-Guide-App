# iOS offline AI integration

Runner now compiles the shared `../native/llama_shim/sn_llama.cpp` bridge and links
llama.cpp through the local `LocalAI` Swift package. The package pins upstream
release b12224 and verifies its archive using SHA-256. Xcode downloads the engine
at build time; no inference server or API key is used.

The upstream binary requires **iOS 16.4 or later**, reflected in Runner and the
package manifest. The existing Flutter retrieval pipeline, streaming worker,
model selection, and Metal offloading remain in use. Linker `-u` flags retain all
eight `sn_llm_*` entry points looked up by Dart even in stripped release builds.

## Use

1. Open the iOS project in Xcode and allow Swift packages to resolve.
2. Build and run on an iPhone with enough available memory.
3. In Library, download a language model from On-device AI models and download
   and index reference documents. The embedding model enables semantic retrieval;
   keyword retrieval remains available without it.
4. Ask a question covered by a downloaded document. Verify streamed text and
   source citations, then test Stop and another question in Airplane Mode.

No model weights are bundled. Until a model and searchable documents are present,
the existing retrieval-only or no-matching-passages messages are expected.

## Native smoke check

`Tests/NativeAI/smoke.cpp` checks unloaded state, missing-model errors, cancellation,
and repeated unload against the actual engine. With the release XCFramework
extracted, run:

```sh
sh Tests/NativeAI/run-smoke.sh /absolute/path/to/llama.xcframework
```

The smoke check and a separate arm64 iOS compilation passed. Full app validation
was blocked by Xcode reporting "Could not compute dependency graph: Failed to
receive dependency graph response" before compilation. Real-model output and
iPhone memory behavior still require the device walkthrough above.
