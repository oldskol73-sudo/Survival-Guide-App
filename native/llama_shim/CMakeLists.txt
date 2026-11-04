# Builds libsn_llama.so (Android, via android/app/build.gradle externalNativeBuild) with llama.cpp
# statically linked. For iOS, build the same sources into the Runner target (see ios/README_NATIVE.md).
#
#   git submodule add https://github.com/ggml-org/llama.cpp native/third_party/llama.cpp
#   cd native/third_party/llama.cpp && git checkout <pinned tag>   # pin: the shim targets the 2026 API

cmake_minimum_required(VERSION 3.22)
project(sn_llama CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static llama/ggml archives are linked into a shared library, so they must be position-independent.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(LLAMA_DIR ${CMAKE_CURRENT_LIST_DIR}/../third_party/llama.cpp)

# Mobile-friendly llama.cpp options: CPU backend, no tools/tests/server, no curl (no network code at all).
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)   # cross-compiling: do not probe the build machine's CPU
if(ANDROID)
  # arm64-v8a: dotprod + i8mm cover most 2020+ SoCs and speed up Q4_K kernels.
  set(GGML_CPU_ARM_ARCH "armv8.2-a+dotprod+i8mm" CACHE STRING "" FORCE)
endif()

add_subdirectory(${LLAMA_DIR} llama_build EXCLUDE_FROM_ALL)

add_library(sn_llama SHARED sn_llama.cpp)
target_link_libraries(sn_llama PRIVATE llama)
target_compile_options(sn_llama PRIVATE -O3 -fvisibility=hidden)
if(ANDROID)
  # 16 KB page alignment, required for apps targeting Android 15+ on 16 KB-page devices.
  target_link_options(sn_llama PRIVATE "-Wl,-z,max-page-size=16384")
endif()
