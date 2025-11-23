#!/usr/bin/env bash
# HyperFFactory - Worker 4: Reporter Basic
# من semantic → serving + reports

set -euo pipefail

ROOT="/root/HyperFFactory"
SEM="$ROOT/data/semantic"
SERV="$ROOT/data/serving"
REPORT_DIR="$ROOT/reports"
LOG_DIR="$ROOT/logs"
RUN_LOG="$LOG_DIR/reporter_basic_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$SEM" "$SERV" "$REPORT_DIR" "$LOG_DIR"

SUMMARY_JSON="$SERV/semantic_serving_summary.json"
OVERVIEW_TXT="$REPORT_DIR/semantic_overview.txt"

echo "==================================================" | tee "$RUN_LOG"
echo "📊 REPORTER_BASIC START $(date '+%F %T')" | tee -a "$RUN_LOG"
echo "SEM   : $SEM" | tee -a "$RUN_LOG"
echo "SERV  : $SERV" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"

mapfile -t FILES < <(find "$SEM" -type f -name '*.semantic.json' -print)
TOTAL="${#FILES[@]}"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "ℹ️ لا توجد ملفات semantic لإنشاء تقرير." | tee -a "$RUN_LOG"
  exit 0
fi

echo "📊 عدد ملفات semantic: $TOTAL" | tee -a "$RUN_LOG"

# بناء JSON مجمّع بسيط
{
  echo '{'
  echo '  "generated_at": "'"$(date '+%F %T')"'",'
  echo '  "count": '"$TOTAL"',' 
  echo '  "items": ['
  first=1
  for f in "${FILES[@]}"; do
    if [[ $first -eq 0 ]]; then
      echo '    ,'
    fi
    first=0
    sed 's/^/    /' "$f"
  done
  echo '  ]'
  echo '}'
} >"$SUMMARY_JSON"

echo "✅ SUMMARY JSON: $SUMMARY_JSON" | tee -a "$RUN_LOG"

# تقرير نصّي مبسّط
{
  echo "================ SEMANTIC OVERVIEW ================"
  echo "Generated at: $(date '+%F %T')"
  echo "Count       : $TOTAL"
  echo "Root        : $SEM"
  echo "==================================================="
  for f in "${FILES[@]}"; do
    base="$(basename "$f")"
    size_class="$(grep -E '"size_class"' "$f" | sed 's/.*: *"//; s/".*//')"
    echo "- $base  [size_class=$size_class]"
  done
} >"$OVERVIEW_TXT"

echo "✅ OVERVIEW TXT: $OVERVIEW_TXT" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
echo "✅ REPORTER_BASIC DONE" | tee -a "$RUN_LOG"
echo "LOG: $RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
