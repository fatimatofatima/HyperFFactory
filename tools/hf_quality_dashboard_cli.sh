#!/usr/bin/env bash
# HyperFFactory – Quality & Meta Dashboard (READ-ONLY)

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"

META_DIR="$ROOT/db/meta"

DB_TASKS="$META_DIR/hf_tasks.db"
DB_QUALITY="$META_DIR/hf_quality.db"
DB_LEARNING="$META_DIR/hf_learning.db"
DB_ERRORS="$META_DIR/hf_errors.db"
DB_CHANGES="$META_DIR/hf_changes.db"
DB_OPS_META="$META_DIR/hf_ops_meta.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت: apt-get update && apt-get install -y sqlite3"
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Quality / Meta Dashboard (CLI)"
echo " ROOT: $ROOT"
echo " TIME: $NOW"
echo "=================================================="
echo

print_db_section() {
  local label="$1"; shift
  local db_path="$1"; shift

  echo "--------------------------------------------------"
  echo "[$label] $db_path"

  if [ ! -f "$db_path" ]; then
    echo "  ↳ ❌ الملف غير موجود"
    echo
    return
  fi

  local size
  size=$(stat -c '%s' "$db_path" 2>/dev/null || echo "?")
  echo "  ↳ الحجم: ${size} bytes"

  local icheck
  icheck=$(sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
  echo "  ↳ integrity_check: $icheck"

  if [ "$#" -eq 0 ]; then
    echo "  (لا توجد جداول محددة للفحص في هذا القسم)"
    echo
    return
  fi

  local tbl exists cnt
  for tbl in "$@"; do
    exists=$(sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='$tbl';" 2>/dev/null || echo "")
    if [ -n "$exists" ]; then
      cnt=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM \"$tbl\";" 2>/dev/null || echo "?")
      printf "  - %-20s : %s صف\n" "$tbl" "$cnt"
    else
      printf "  - %-20s : (لا يوجد جدول بهذا الاسم)\n" "$tbl"
    fi
  done

  echo
}

# 1) مهام HyperFFactory (hf_tasks.db)
print_db_section "CORE TASKS" "$DB_TASKS" \
  "tasks"

# 2) جودة HyperFFactory (hf_quality.db)
print_db_section "CORE QUALITY" "$DB_QUALITY" \
  "quality_checks" \
  "quality_metrics" \
  "quality_runs" \
  "quality_events"

# 3) التعلم والخبرة (hf_learning.db)
print_db_section "CORE LEARNING" "$DB_LEARNING" \
  "learning" \
  "lessons_learned" \
  "learning_events" \
  "learning_jobs" \
  "learning_skill_states" \
  "experiences" \
  "scripts"

# 4) الأخطاء والحوادث (hf_errors.db)
print_db_section "CORE ERRORS" "$DB_ERRORS" \
  "errors" \
  "error_events" \
  "error_stats"

# 5) سجل التغييرات (hf_changes.db)
print_db_section "CORE CHANGES" "$DB_CHANGES" \
  "changes" \
  "hf_changes"

# 6) ميتا التشغيل (hf_ops_meta.db)
print_db_section "OPS META" "$DB_OPS_META" \
  "tasks" \
  "progress_log" \
  "experiences" \
  "incidents" \
  "quality_checks"

echo "=================================================="
echo " نهاية تقرير لوحة الجودة / الميتا"
echo "=================================================="
