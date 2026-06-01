#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/third_party/libexpat/expat"
OUT_DIR="$ROOT_DIR/results/static-analysis"
SCAN_BUILD_DIR="$OUT_DIR/scan-build"

mkdir -p "$OUT_DIR" "$SCAN_BUILD_DIR"

if command -v cppcheck >/dev/null 2>&1; then
  cppcheck --enable=warning,style,performance,portability \
    --inline-suppr \
    --xml --xml-version=2 \
    -DHAVE_EXPAT_CONFIG_H \
    -DXML_STATIC \
    -DXML_NS \
    -DXML_DTD \
    -DXML_GE=1 \
    -DXML_CONTEXT_BYTES=1024 \
    -I "$ROOT_DIR/build/libexpat-asan" \
    -I "$SRC_DIR/lib" \
    "$SRC_DIR/lib" \
    2> "$OUT_DIR/cppcheck.xml"

  cppcheck --enable=warning,style,performance,portability \
    --inline-suppr \
    -DHAVE_EXPAT_CONFIG_H \
    -DXML_STATIC \
    -DXML_NS \
    -DXML_DTD \
    -DXML_GE=1 \
    -DXML_CONTEXT_BYTES=1024 \
    -I "$ROOT_DIR/build/libexpat-asan" \
    -I "$SRC_DIR/lib" \
    "$SRC_DIR/lib" \
    > "$OUT_DIR/cppcheck.txt" 2>&1
else
  echo "cppcheck not found; skipping Cppcheck" | tee "$OUT_DIR/cppcheck.txt"
fi

SCAN_BUILD_BIN=""
if command -v scan-build >/dev/null 2>&1; then
  SCAN_BUILD_BIN="$(command -v scan-build)"
elif [[ -x /opt/homebrew/opt/llvm/bin/scan-build ]]; then
  SCAN_BUILD_BIN=/opt/homebrew/opt/llvm/bin/scan-build
fi

if [[ -n "$SCAN_BUILD_BIN" ]]; then
  rm -rf "$SCAN_BUILD_DIR"/*
  "$SCAN_BUILD_BIN" -o "$SCAN_BUILD_DIR" \
    cmake -S "$SRC_DIR" -B "$ROOT_DIR/build/scan-build" \
      -DCMAKE_BUILD_TYPE=Debug \
      -DEXPAT_BUILD_DOCS=OFF \
      -DEXPAT_BUILD_EXAMPLES=OFF \
      -DEXPAT_BUILD_TESTS=OFF \
      -DEXPAT_BUILD_TOOLS=OFF \
      -DEXPAT_SHARED_LIBS=OFF
  "$SCAN_BUILD_BIN" -o "$SCAN_BUILD_DIR" cmake --build "$ROOT_DIR/build/scan-build" --clean-first \
    > "$OUT_DIR/scan-build.txt" 2>&1 || true
else
  echo "scan-build not found; skipping Clang Static Analyzer" | tee "$OUT_DIR/scan-build.txt"
fi

echo "static analysis results saved to: $OUT_DIR"
