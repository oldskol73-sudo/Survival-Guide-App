#!/bin/sh
set -eu

# Usage: sh ios/Tests/NativeAI/run-smoke.sh /path/to/llama.xcframework
framework_root=${1:?Pass the extracted llama.xcframework directory}
framework_dir="$framework_root/macos-arm64_x86_64"
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$test_dir/../../.." && pwd)
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/blackout-ai-smoke.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT HUP INT TERM

xcrun clang++ -std=c++17 \
    -I "$framework_dir/llama.framework/Headers" \
    -F "$framework_dir" -framework llama \
    -Wl,-rpath,"$framework_dir" \
    "$repo_dir/native/llama_shim/sn_llama.cpp" "$test_dir/smoke.cpp" \
    -o "$output_dir/smoke"
"$output_dir/smoke"
echo 'Native AI smoke checks passed.'
