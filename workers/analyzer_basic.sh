#!/usr/bin/env bash
# HyperFFactory - Worker 3: Analyzer Basic
# من processed (metadata) → semantic (semantic JSON)

set -euo pipefail

ROOT="/root/HyperFFactory"
PROC="$ROOT/data/processed"
SEM="$ROOT/data/semantic"
LOG_DIR="$ROOT/logs"
RUN_LOG="$LOG_DIR/analyzer_basic_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$PROC" "$SEM" "$LOG_DIR"

echo "==================================================" | tee "$RUN_LOG"
echo "🔍 ANALYZER_BASIC START $(date '+%F %T')" | tee -a "$RUN_LOG"
echo "PROC  : $PROC" | tee -a "$RUN_LOG"
echo "SEM   : $SEM" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"

mapfile -t FILES < <(find "$PROC" -type f -name '*.meta.json' -print)
TOTAL="${#FILES[@]}"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "ℹ️ لا توجد ملفات meta لمعالجتها." | tee -a "$RUN_LOG"
  exit 0
fi

echo "📊 عدد ملفات meta: $TOTAL" | tee -a "$RUN_LOG"

process_one() {
  local meta="$1"
  local base
  base="$(basename "$meta" .meta.json)"
  local out="$SEM/${base}.semantic.json"

  # قراءة بعض الحقول من meta (بشكل بسيط)
  local size sha
  size="$(grep -E '"size_bytes"' "$meta" | sed 's/[^0-9]//g' | head -n1)"
  sha="$(grep -E '"sha256"' "$meta" | sed 's/.*: *"//; s/".*//')"

  local size_class="small"
  if [[ "$size" -gt 10485760 ]]; then
    size_class="large"
  elif [[ "$size" -gt 1048576 ]]; then
    size_class="medium"
  fi

  cat >"$out" <<JSON
{
  "meta_file": "$meta",
  "semantic_key": "file://$base",
  "size_bytes": ${size:-0},
  "size_class": "$size_class",
  "sha256": "$sha",
  "tags": [
    "hyperffactory",
    "ingested_file",
    "size_${size_class}"
  ],
  "analyzed_at": "$(date '+%F %T')"
}
JSON

  echo "✅ SEMANTIC: $meta → $out" >>"$RUN_LOG"
}

export -f process_one
export SEM RUN_LOG

printf "%s\n" "${FILES[@]}" | xargs -r -n1 -P6 bash -c 'process_one "$@"' _

SEM_COUNT="$(grep -c '^✅ SEMANTIC:' "$RUN_LOG" || true)"
echo "==================================================" | tee -a "$RUN_LOG"
echo "✅ ANALYZER_BASIC DONE - SEM=$SEM_COUNT / TOTAL=$TOTAL" | tee -a "$RUN_LOG"
echo "LOG: $RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
