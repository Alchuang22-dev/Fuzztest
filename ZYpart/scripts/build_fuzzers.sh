#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/third_party/libexpat/expat"
BUILD_DIR="$ROOT_DIR/build/libexpat-apple-asan"
CUSTOM_BUILD_DIR="$ROOT_DIR/build/custom-fuzzer"
AFL_BUILD_DIR="$ROOT_DIR/build/libexpat-afl"
AFL_BIN_DIR="$ROOT_DIR/build/afl"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_tool cmake
CLANG="${CLANG:-clang}"
CLANGXX="${CLANGXX:-clang++}"
require_tool "$CLANG"
require_tool "$CLANGXX"

if command -v ninja >/dev/null 2>&1; then
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_C_COMPILER="$CLANG" \
    -DCMAKE_CXX_COMPILER="$CLANGXX" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_C_FLAGS="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined" \
    -DCMAKE_CXX_FLAGS="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
    -DEXPAT_BUILD_DOCS=OFF \
    -DEXPAT_BUILD_EXAMPLES=OFF \
    -DEXPAT_BUILD_TESTS=OFF \
    -DEXPAT_BUILD_TOOLS=OFF \
    -DEXPAT_SHARED_LIBS=OFF \
    -DEXPAT_BUILD_FUZZERS=OFF
else
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_FLAGS="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined" \
  -DCMAKE_CXX_FLAGS="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DEXPAT_BUILD_DOCS=OFF \
  -DEXPAT_BUILD_EXAMPLES=OFF \
  -DEXPAT_BUILD_TESTS=OFF \
  -DEXPAT_BUILD_TOOLS=OFF \
  -DEXPAT_SHARED_LIBS=OFF \
  -DEXPAT_BUILD_FUZZERS=OFF
fi

cmake --build "$BUILD_DIR"

mkdir -p "$CUSTOM_BUILD_DIR"
LIBEXPAT_A="$(find "$BUILD_DIR" -name 'libexpat.a' -print -quit)"
if [[ -z "$LIBEXPAT_A" ]]; then
  echo "could not find libexpat.a under $BUILD_DIR" >&2
  exit 1
fi

"$CLANG" -g -O1 -fno-omit-frame-pointer \
  -fsanitize=address,undefined \
  -I"$SRC_DIR/lib" \
  "$ROOT_DIR/fuzz/expat_file_harness.c" \
  "$LIBEXPAT_A" \
  -o "$CUSTOM_BUILD_DIR/expat_file_harness_asan"

if command -v afl-clang-fast >/dev/null 2>&1; then
  AFL_USE_ASAN=1 cmake -S "$SRC_DIR" -B "$AFL_BUILD_DIR" \
    -DCMAKE_C_COMPILER=afl-clang-fast \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_C_FLAGS="-g -O1 -fno-omit-frame-pointer" \
    -DEXPAT_BUILD_DOCS=OFF \
    -DEXPAT_BUILD_EXAMPLES=OFF \
    -DEXPAT_BUILD_TESTS=OFF \
    -DEXPAT_BUILD_TOOLS=OFF \
    -DEXPAT_SHARED_LIBS=OFF \
    -DEXPAT_BUILD_FUZZERS=OFF
  AFL_USE_ASAN=1 cmake --build "$AFL_BUILD_DIR"

  AFL_LIBEXPAT_A="$(find "$AFL_BUILD_DIR" -name 'libexpat.a' -print -quit)"
  if [[ -z "$AFL_LIBEXPAT_A" ]]; then
    echo "could not find AFL-instrumented libexpat.a under $AFL_BUILD_DIR" >&2
    exit 1
  fi

  mkdir -p "$AFL_BIN_DIR"
  AFL_USE_ASAN=1 afl-clang-fast -g -O1 -fno-omit-frame-pointer \
    -I"$SRC_DIR/lib" \
    "$ROOT_DIR/fuzz/expat_file_harness.c" \
    "$AFL_LIBEXPAT_A" \
    -o "$AFL_BIN_DIR/expat_file_harness"
  echo "built AFL++ harness: $AFL_BIN_DIR/expat_file_harness"
else
  echo "afl-clang-fast not found; skipping AFL++ harness"
fi

echo "built ASAN replay harness: $CUSTOM_BUILD_DIR/expat_file_harness_asan"
echo "linked library: $LIBEXPAT_A"
echo "libFuzzer source is available at fuzz/expat_stream_fuzzer.c for LLVM environments with libFuzzer runtime."
