#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECONDS_TO_RUN="${1:-60}"
HARNESS="$ROOT_DIR/build/afl/expat_file_harness"
INPUTS="$ROOT_DIR/fuzz/seeds"
DICT="$ROOT_DIR/fuzz/dict/xml.dict"
OUTPUTS="$ROOT_DIR/results/fuzzing/afl-expat"
LOG="$ROOT_DIR/results/fuzzing/afl-expat-$(date +%Y%m%d-%H%M%S).log"

if ! command -v afl-fuzz >/dev/null 2>&1; then
  echo "afl-fuzz not found; install AFL++ first" >&2
  exit 1
fi

if [[ ! -x "$HARNESS" ]]; then
  echo "AFL++ harness not found: $HARNESS" >&2
  echo "run ./scripts/build_fuzzers.sh first" >&2
  exit 1
fi

mkdir -p "$OUTPUTS" "$(dirname "$LOG")"

AFL_MAP_SIZE="${AFL_MAP_SIZE:-1000000}" \
AFL_SKIP_CPUFREQ=1 AFL_NO_UI=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
  afl-fuzz -V "$SECONDS_TO_RUN" -i "$INPUTS" -o "$OUTPUTS" -x "$DICT" -- "$HARNESS" @@ \
  2>&1 | tee "$LOG" || true

echo "AFL++ output saved to: $OUTPUTS"
echo "log saved to: $LOG"
