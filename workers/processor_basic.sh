#!/usr/bin/env bash
# HyperFFactory - Worker 2: Processor Basic
# من raw → processed (metadata JSON)

set -euo pipefail

ROOT="/root/HyperFFactory"
RAW="$ROOT/data/raw"
PROC="$ROOT/data/processed"
LOG_DIR="$ROOT/logs"
RUN_LOG="$LOG_DIR/processor_basic_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$RAW" "$PROC" "$LOG_DIR"

echo "==================================================" | tee "$RUN_LOG"
echo "🛠 PROCESSOR_BASIC START $(date '+%F %T')" | tee -a "$RUN_LOG"
echo "RAW   : $RAW" | tee -a "$RUN_LOG"
echo "PROC  : $PROC" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"

mapfile -t FILES < <(find "$RAW" -type f ! -name '*.meta.json' -print)
TOTAL="${#FILES[@]}"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "ℹ️ لا توجد ملفات جديدة في raw." | tee -a "$RUN_LOG"
  exit 0
fi

echo "📊 عدد الملفات المراد معالجتها: $TOTAL" | tee -a "$RUN_LOG"

process_one() {
  local src="$1"
  local base
  base="$(basename "$src")"
  local meta="$PROC/${base}.meta.json"

  local size mtime sha
  size="$(stat -c%s "$src" 2>/dev/null || stat -f%z "$src")"
  mtime="$(date -d "@$(stat -c%Y "$src" 2>/dev/null || stat -f%m "$src")" '+%F %T' 2>/dev/null || date '+%F %T')"
  sha="$(sha256sum "$src" 2>/dev/null | awk '{print $1}')"

  cat >"$meta" <<JSON
{
  "source_path": "$src",
  "file_name": "$base",
  "size_bytes": $size,
  "mtime": "$mtime",
  "sha256": "$sha",
  "processed_at": "$(date '+%F %T')"
}
JSON

  echo "✅ META: $src → $meta" >>"$RUN_LOG"
}

export -f process_one
export PROC RUN_LOG

printf "%s\n" "${FILES[@]}" | xargs -r -n1 -P6 bash -c 'process_one "$@"' _

META_COUNT="$(grep -c '^✅ META:' "$RUN_LOG" || true)"
echo "==================================================" | tee -a "$RUN_LOG"
echo "✅ PROCESSOR_BASIC DONE - META=$META_COUNT / TOTAL=$TOTAL" | tee -a "$RUN_LOG"
echo "LOG: $RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
