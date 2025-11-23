#!/usr/bin/env bash
# HyperFFactory - Workers Status Report
# - فحص حالة "العمال" (actors) من قواعد:
#   * hf_quality.db   (quality_checks)
#   * hf_errors.db    (errors)
#   * hf_learning.db  (learning)
#   * hf_tasks.db     (tasks)
# - بدون أي حذف أو تعديل على البيانات
# - مع تسجيل التقدّم في hf_changes.db عبر hf_progress_log.sh لو موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"
PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

log_progress() {
  local msg="${1:-INFO}"
  if [[ -x "$PROGRESS_LOG" ]]; then
    "$PROGRESS_LOG" "hf_workers_status" "$msg" || true
  fi
}

check_table() {
  # usage: check_table /path/to/db.sqlite table_name
  local db="$1"
  local tbl="$2"
  if [[ ! -f "$db" ]]; then
    return 1
  fi
  local found
  found="$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='$tbl';")" || return 2
  if [[ -z "$found" ]]; then
    return 2
  fi
  return 0
}

echo "=================================================="
echo "👷 HyperFFactory – Workers Status"
echo "📍 Root : $ROOT_DIR"
echo "📂 DBs  : $DB_DIR"
echo "=================================================="

if [[ ! -d "$DB_DIR" ]]; then
  echo "⚠️ مجلد قواعد البيانات meta غير موجود: $DB_DIR"
  echo "⚠️ شغّل بايبلاين الصحة/التهيئة أولاً."
  exit 0
fi

# 1) جودة العمال من hf_quality.db
echo
echo "== جودة العمال (من hf_quality.db / جدول quality_checks) =="

QUALITY_DB="$DB_DIR/hf_quality.db"
if ! check_table "$QUALITY_DB" "quality_checks"; then
  if [[ -f "$QUALITY_DB" ]]; then
    echo "⚠️ hf_quality.db موجود لكن جدول quality_checks غير موجود."
  else
    echo "⚠️ لا يوجد hf_quality.db حتى الآن (لم تُسجل أي فحوص جودة)."
  fi
else
  sqlite3 "$QUALITY_DB" -header -column "
    SELECT
      actor,
      COUNT(*)                                           AS checks,
      SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END)  AS pass_cnt,
      SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END)  AS fail_cnt,
      SUM(CASE WHEN result = 'WARN' THEN 1 ELSE 0 END)  AS warn_cnt,
      MIN(ts)                                           AS first_ts,
      MAX(ts)                                           AS last_ts,
      printf('%.1f', AVG(score))                        AS avg_score
    FROM quality_checks
    GROUP BY actor
    ORDER BY last_ts DESC;
  "
fi

# 2) أخطاء العمال من hf_errors.db
echo
echo "== أخطاء العمال (من hf_errors.db / جدول errors) =="

ERRORS_DB="$DB_DIR/hf_errors.db"
if ! check_table "$ERRORS_DB" "errors"; then
  if [[ -f "$ERRORS_DB" ]]; then
    echo "⚠️ hf_errors.db موجود لكن جدول errors غير موجود."
  else
    echo "⚠️ لا يوجد hf_errors.db حتى الآن (لم تُسجل أي أخطاء)."
  fi
else
  sqlite3 "$ERRORS_DB" -header -column "
    SELECT
      actor,
      COUNT(*)                             AS errors_cnt,
      GROUP_CONCAT(DISTINCT severity)      AS severities,
      MIN(ts)                              AS first_error_ts,
      MAX(ts)                              AS last_error_ts
    FROM errors
    GROUP BY actor
    ORDER BY last_error_ts DESC;
  "
fi

# 3) خبرة/أنماط العمال من hf_learning.db
echo
echo "== خبرة/أنماط العمال (من hf_learning.db / جدول learning) =="

LEARNING_DB="$DB_DIR/hf_learning.db"
if ! check_table "$LEARNING_DB" "learning"; then
  if [[ -f "$LEARNING_DB" ]]; then
    echo "⚠️ hf_learning.db موجود لكن جدول learning غير موجود."
    echo "   👉 شغّل: bin/hf_learning_init.sh لإنشاء الجدول بدون لمس البيانات."
  else
    echo "⚠️ لا يوجد hf_learning.db حتى الآن (لم تُسجل أي أنماط خبرة)."
  fi
else
  sqlite3 "$LEARNING_DB" -header -column "
    SELECT
      source                                        AS actor,
      COUNT(*)                                      AS patterns_cnt,
      printf('%.2f', AVG(COALESCE(confidence,0)))   AS avg_confidence,
      MIN(ts)                                       AS first_ts,
      MAX(ts)                                       AS last_ts
    FROM learning
    GROUP BY source
    ORDER BY patterns_cnt DESC, last_ts DESC;
  "
fi

# 4) حالة المهام من hf_tasks.db
echo
echo "== مهام العمال (من hf_tasks.db / جدول tasks) =="

TASKS_DB="$DB_DIR/hf_tasks.db"
if ! check_table "$TASKS_DB" "tasks"; then
  if [[ -f "$TASKS_DB" ]]; then
    echo "⚠️ hf_tasks.db موجود لكن جدول tasks غير موجود."
  else
    echo "⚠️ لا يوجد hf_tasks.db حتى الآن (نظام المهام إما جديد أو لم يُستخدم بعد)."
  fi
else
  sqlite3 "$TASKS_DB" -header -column "
    SELECT
      actor,
      COUNT(*)                                                AS tasks_total,
      SUM(CASE WHEN status = 'DONE'    THEN 1 ELSE 0 END)    AS done_cnt,
      SUM(CASE WHEN status = 'RUNNING' THEN 1 ELSE 0 END)    AS running_cnt,
      SUM(CASE WHEN status = 'FAILED'  THEN 1 ELSE 0 END)    AS failed_cnt,
      SUM(CASE WHEN status = 'PLANNED' THEN 1 ELSE 0 END)    AS planned_cnt,
      SUM(CASE WHEN status = 'SKIPPED' THEN 1 ELSE 0 END)    AS skipped_cnt,
      MIN(created_at)                                         AS first_task,
      MAX(COALESCE(updated_at, created_at))                   AS last_task
    FROM tasks
    GROUP BY actor
    ORDER BY last_task DESC;
  "
fi

log_progress "INFO"

echo
echo "=================================================="
echo "✅ تقرير حالة العمال (workers status) جاهز"
echo "=================================================="
