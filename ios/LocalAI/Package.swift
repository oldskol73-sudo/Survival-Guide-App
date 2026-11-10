// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalAI",
    platforms: [.iOS("16.4")],
    products: [.library(name: "LocalAI", targets: ["llama"])],
    targets: [
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b12224/llama-b12224-xcframework.zip",
            checksum: "d59cd2b2547a1968797b1be3d6c5e6c7bd6a5cff390224ae4c4e96a2c6908512"
        )
    ]
)
