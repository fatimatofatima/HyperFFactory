#!/usr/bin/env bash
# HyperFFactory - Worker 1: Ingestor Basic
# من inbox → raw باستخدام 6 أنوية مع عدّاد تقدّم بسيط

set -euo pipefail

ROOT="/root/HyperFFactory"
INBOX="$ROOT/data/inbox"
RAW="$ROOT/data/raw"
LOG_DIR="$ROOT/logs"
RUN_LOG="$LOG_DIR/ingestor_basic_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$INBOX" "$RAW" "$LOG_DIR"

echo "==================================================" | tee "$RUN_LOG"
echo "📥 INGESTOR_BASIC START $(date '+%F %T')" | tee -a "$RUN_LOG"
echo "INBOX: $INBOX" | tee -a "$RUN_LOG"
echo "RAW  : $RAW" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"

# جمع الملفات
mapfile -t FILES < <(find "$INBOX" -type f -print)
TOTAL="${#FILES[@]}"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "ℹ️ لا توجد ملفات في inbox." | tee -a "$RUN_LOG"
  exit 0
fi

echo "📊 عدد الملفات المراد نقلها: $TOTAL" | tee -a "$RUN_LOG"

export RAW LOG_DIR RUN_LOG

# دالة معالجة ملف واحد
process_one() {
  local src="$1"
  local base
  base="$(basename "$src")"
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local dst="$RAW/${ts}_$base"

  mv "$src" "$dst"
  echo "✅ MOVED: $src → $dst" >>"$RUN_LOG"
}

export -f process_one

# تنفيذ متوازي بـ 6 أنوية
printf "%s\n" "${FILES[@]}" | xargs -r -n1 -P6 bash -c 'process_one "$@"' _

MOVED_COUNT="$(grep -c '^✅ MOVED:' "$RUN_LOG" || true)"
echo "==================================================" | tee -a "$RUN_LOG"
echo "✅ INGESTOR_BASIC DONE - MOVED=$MOVED_COUNT / TOTAL=$TOTAL" | tee -a "$RUN_LOG"
echo "LOG: $RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
