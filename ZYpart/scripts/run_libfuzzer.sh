#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECONDS_TO_RUN="${1:-60}"
FUZZER="$ROOT_DIR/build/custom-fuzzer/expat_stream_fuzzer"
SEEDS="$ROOT_DIR/fuzz/seeds"
DICT="$ROOT_DIR/fuzz/dict/xml.dict"
CORPUS="$ROOT_DIR/results/fuzzing/corpus-expat-stream"
ARTIFACTS="$ROOT_DIR/results/crashes"
LOG="$ROOT_DIR/results/fuzzing/libfuzzer-expat-stream-$(date +%Y%m%d-%H%M%S).log"

if [[ ! -x "$FUZZER" ]]; then
  echo "fuzzer not found: $FUZZER" >&2
  echo "run ./scripts/build_fuzzers.sh first" >&2
  exit 1
fi

mkdir -p "$CORPUS" "$ARTIFACTS" "$(dirname "$LOG")"
cp "$SEEDS"/* "$CORPUS"/

"$FUZZER" "$CORPUS" \
  -dict="$DICT" \
  -max_total_time="$SECONDS_TO_RUN" \
  -artifact_prefix="$ARTIFACTS/" \
  -print_final_stats=1 \
  2>&1 | tee "$LOG"

echo "log saved to: $LOG"
