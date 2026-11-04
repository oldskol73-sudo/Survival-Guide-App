// sn_zim: minimal C ABI over libzim (C++) for dart:ffi. Reads entries from .zim archives so the app's
// loopback server can hand them to a WebView. Archive reads are thread-safe in libzim.
//
// Build: link against libzim built for the target with kiwix-build (android_arm64 / iOS_arm64),
// which also brings zstd, xz, ICU and Xapian.

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>

#include <zim/archive.h>
#include <zim/error.h>
#include <zim/item.h>
#include <zim/suggestion.h>

#define SN_API extern "C" __attribute__((visibility("default"))) __attribute__((used))

namespace {
std::mutex g_mu;
std::map<int32_t, std::unique_ptr<zim::Archive>> g_archives;
int32_t g_next = 1;
thread_local std::string g_err;

zim::Archive *get(int32_t h) {
  std::lock_guard<std::mutex> lock(g_mu);
  auto it = g_archives.find(h);
  return it == g_archives.end() ? nullptr : it->second.get();
}

void copy_str(const std::string &s, char *out, int32_t cap) {
  if (!out || cap <= 0) return;
  size_t n = std::min<size_t>(s.size(), (size_t)cap - 1);
  std::memcpy(out, s.data(), n);
  out[n] = '\0';
}
}  // namespace

// Returns a handle > 0, or -1 (see sn_zim_last_error).
SN_API int32_t sn_zim_open(const char *path) {
  try {
    auto a = std::make_unique<zim::Archive>(std::string(path));
    std::lock_guard<std::mutex> lock(g_mu);
    int32_t h = g_next++;
    g_archives[h] = std::move(a);
    return h;
  } catch (const std::exception &e) {
    g_err = e.what();
    return -1;
  }
}

SN_API void sn_zim_close(int32_t h) {
  std::lock_guard<std::mutex> lock(g_mu);
  g_archives.erase(h);
}

// Writes the main page path into `out`. Returns 0, or -1 if the archive has no main page.
SN_API int32_t sn_zim_main_path(int32_t h, char *out, int32_t cap) {
  auto *a = get(h);
  if (!a) return -1;
  try {
    copy_str(a->getMainEntry().getItem(true).getPath(), out, cap);
    return 0;
  } catch (const std::exception &e) {
    g_err = e.what();
    return -1;
  }
}

// Reads an entry (following redirects). On success returns 0 and sets *data (malloc'd; free with
// sn_zim_free), *size and the MIME type. Returns 1 if not found, -1 on error.
SN_API int32_t sn_zim_get(int32_t h, const char *path, uint8_t **data, int64_t *size, char *mime, int32_t mime_cap) {
  auto *a = get(h);
  if (!a) return -1;
  try {
    zim::Item item = a->getEntryByPath(std::string(path)).getItem(true);
    zim::Blob blob = item.getData();
    auto *buf = static_cast<uint8_t *>(std::malloc(blob.size() > 0 ? (size_t)blob.size() : 1));
    if (!buf) return -1;
    if (blob.size() > 0) std::memcpy(buf, blob.data(), (size_t)blob.size());
    *data = buf;
    *size = (int64_t)blob.size();
    copy_str(item.getMimetype(), mime, mime_cap);
    return 0;
  } catch (const zim::EntryNotFound &) {
    return 1;
  } catch (const std::exception &e) {
    g_err = e.what();
    return -1;
  }
}

// Title suggestions as "path\ttitle\n" lines. Returns the number of results, or -1.
SN_API int32_t sn_zim_suggest(int32_t h, const char *query, int32_t max_results, char *out, int32_t cap) {
  auto *a = get(h);
  if (!a) return -1;
  try {
    zim::SuggestionSearcher searcher(*a);
    auto results = searcher.suggest(std::string(query)).getResults(0, max_results);
    std::string acc;
    int32_t n = 0;
    for (auto it = results.begin(); it != results.end(); ++it) {
      acc += it->getPath();
      acc += '\t';
      acc += it->getTitle();
      acc += '\n';
      ++n;
    }
    copy_str(acc, out, cap);
    return n;
  } catch (const std::exception &e) {
    g_err = e.what();
    return -1;
  }
}

SN_API void sn_zim_free(void *p) { std::free(p); }

SN_API const char *sn_zim_last_error(void) { return g_err.c_str(); }
