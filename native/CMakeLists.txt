# Android entry point for all native code (wired from android/app/build.gradle.kts):
#   libsn_llama.so   llama.cpp shim            (always)
#   libsqlite_vec.so sqlite-vec loadable ext.  (always; app falls back to brute force if absent)
#   libsn_zim.so     libzim shim               (only if a prebuilt libzim for the ABI is present)

cmake_minimum_required(VERSION 3.22)
project(survival_node_native C CXX)

add_subdirectory(llama_shim)

# ---- sqlite-vec: built as a *loadable* extension (no SQLITE_CORE), so it uses the sqlite3_api
# routines handed over by the sqlite3 Dart package at registration time.
#   git submodule add https://github.com/asg017/sqlite-vec native/third_party/sqlite-vec
#   (run its `make sqlite-vec.h` once, or copy a release's amalgamation: sqlite-vec.c + sqlite-vec.h)
set(SQLITE_VEC_DIR ${CMAKE_CURRENT_LIST_DIR}/third_party/sqlite-vec)
add_library(sqlite_vec SHARED ${SQLITE_VEC_DIR}/sqlite-vec.c)
target_include_directories(sqlite_vec PRIVATE ${SQLITE_VEC_DIR} ${CMAKE_CURRENT_LIST_DIR}/third_party/sqlite-headers)
target_compile_definitions(sqlite_vec PRIVATE SQLITE_VEC_OMIT_FS=1)
target_compile_options(sqlite_vec PRIVATE -O3)
target_link_options(sqlite_vec PRIVATE "-Wl,-z,max-page-size=16384")

# ---- libzim shim: expects kiwix-build output in third_party/libzim/<ABI>/{include,lib}
set(LIBZIM_PREFIX ${CMAKE_CURRENT_LIST_DIR}/third_party/libzim/${ANDROID_ABI})
if(EXISTS ${LIBZIM_PREFIX}/lib/libzim.so)
  add_library(zim SHARED IMPORTED)
  set_target_properties(zim PROPERTIES IMPORTED_LOCATION ${LIBZIM_PREFIX}/lib/libzim.so)
  add_library(sn_zim SHARED zim_shim/sn_zim.cpp)
  set_target_properties(sn_zim PROPERTIES CXX_STANDARD 17)
  target_include_directories(sn_zim PRIVATE ${LIBZIM_PREFIX}/include)
  target_link_libraries(sn_zim PRIVATE zim)
  target_link_options(sn_zim PRIVATE "-Wl,-z,max-page-size=16384")
else()
  message(WARNING "libzim not found for ${ANDROID_ABI}: building without the ZIM reader")
endif()
