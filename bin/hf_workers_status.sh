#!/usr/bin/env bash
# HyperFFactory - Workers Status Report (robust)
# - يعرض حالة "العمال" (actors) من قواعد:
#   * hf_quality.db   (quality_checks)
#   * hf_errors.db    (errors)
#   * hf_learning.db  (learning)
#   * hf_tasks.db     (tasks)
# - لا يحذف أي بيانات، قراءة فقط
# - يتعامل مع غياب الجداول/القواعد بدون أخطاء قاتلة
# - يسجّل التقدّم في hf_changes.db عبر hf_progress_log.sh لو موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"

QUALITY_DB="$DB_DIR/hf_quality.db"
ERRORS_DB="$DB_DIR/hf_errors.db"
LEARNING_DB="$DB_DIR/hf_learning.db"
TASKS_DB="$DB_DIR/hf_tasks.db"

PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت، لا يمكن فحص قواعد البيانات"
  exit 1
fi

has_table() {
  local db="$1"
  local table="$2"
  if [ ! -f "$db" ]; then
    return 1
  fi
  sqlite3 "$db" ".tables" | tr ' ' '\n' | grep -qx "$table"
}

echo "=================================================="
echo "👷 HyperFFactory – Workers Status"
echo "📍 Root : $ROOT_DIR"
echo "📂 DBs  : $DB_DIR"
echo "=================================================="

# تسجيل التقدّم لو سكربت اللوج موجود
if [ -x "$PROGRESS_LOG" ]; then
  "$PROGRESS_LOG" "hf_workers_status" "workers_status_start" "INFO" "Workers status report started"
  echo "✅ Progress logged: hf_workers_status [INFO]"
fi

############################################
# 1) جودة العمال من hf_quality.db
############################################
echo
echo "== جودة العمال (من hf_quality.db / جدول quality_checks) =="

if has_table "$QUALITY_DB" "quality_checks"; then
  sqlite3 "$QUALITY_DB" <<'SQL'
.headers on
.mode column
SELECT
  actor,
  COUNT(*) AS checks,
  SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS pass_cnt,
  SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) AS fail_cnt,
  SUM(CASE WHEN result = 'WARN' THEN 1 ELSE 0 END) AS warn_cnt,
  MIN(ts) AS first_ts,
  MAX(ts) AS last_ts,
  ROUND(AVG(score), 1) AS avg_score
FROM quality_checks
GROUP BY actor
ORDER BY last_ts DESC;
SQL
else
  if [ ! -f "$QUALITY_DB" ]; then
    echo "⚠️ لا يوجد hf_quality.db حتى الآن (لم تُسجَّل أي فحوصات جودة)."
  else
    echo "⚠️ قاعدة hf_quality.db موجودة لكن جدول quality_checks غير موجود."
  fi
fi

############################################
# 2) أخطاء العمال من hf_errors.db
############################################
echo
echo "== أخطاء العمال (من hf_errors.db / جدول errors) =="

if has_table "$ERRORS_DB" "errors"; then
  sqlite3 "$ERRORS_DB" <<'SQL'
.headers on
.mode column
SELECT
  actor,
  COUNT(*) AS errors_cnt,
  GROUP_CONCAT(DISTINCT severity) AS severities,
  MIN(ts) AS first_error_ts,
  MAX(ts) AS last_error_ts
FROM errors
GROUP BY actor
ORDER BY last_error_ts DESC;
SQL
else
  if [ ! -f "$ERRORS_DB" ]; then
    echo "ℹ️ لا يوجد hf_errors.db (لم تُسجَّل أي أخطاء/Incidents بعد)."
  else
    echo "⚠️ قاعدة hf_errors.db موجودة لكن جدول errors غير موجود."
  fi
fi

############################################
# 3) خبرة/أنماط العمال من hf_learning.db
############################################
echo
echo "== خبرة/أنماط العمال (من hf_learning.db / جدول learning) =="

if has_table "$LEARNING_DB" "learning"; then
  sqlite3 "$LEARNING_DB" <<'SQL'
.headers on
.mode column
SELECT
  source      AS actor,
  COUNT(*)    AS learning_events,
  ROUND(AVG(COALESCE(confidence, 0.0)), 2) AS avg_confidence,
  MIN(ts)     AS first_ts,
  MAX(ts)     AS last_ts
FROM learning
GROUP BY source
ORDER BY last_ts DESC
LIMIT 50;
SQL
else
  if [ ! -f "$LEARNING_DB" ]; then
    echo "ℹ️ لا يوجد hf_learning.db (لم تبدأ طبقة التعلّم/الخبرة بعد)."
  else
    echo "ℹ️ hf_learning.db موجودة لكن جدول learning غير موجود أو لم يُنشأ بعد."
    echo "👉 يمكنك تشغيل: bin/hf_learning_bootstrap.sh لإنشاء الجدول بأمان."
  fi
fi

############################################
# 4) المهام لكل عامل من hf_tasks.db
############################################`
echo
echo "== مهام العمال (من hf_tasks.db / جدول tasks) =="

if has_table "$TASKS_DB" "tasks"; then
  sqlite3 "$TASKS_DB" <<'SQL'
.headers on
.mode column
SELECT
  actor,
  COUNT(*) AS total,
  SUM(CASE WHEN status = 'PLANNED' THEN 1 ELSE 0 END) AS planned,
  SUM(CASE WHEN status = 'RUNNING' THEN 1 ELSE 0 END) AS running,
  SUM(CASE WHEN status = 'DONE'    THEN 1 ELSE 0 END) AS done,
  SUM(CASE WHEN status = 'FAILED'  THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN status = 'SKIPPED' THEN 1 ELSE 0 END) AS skipped,
  MIN(created_at) AS first_created,
  MAX(updated_at) AS last_update
FROM tasks
GROUP BY actor
ORDER BY last_update DESC;
SQL
else
  if [ ! -f "$TASKS_DB" ]; then
    echo "ℹ️ لا يوجد hf_tasks.db (لم تُسجَّل مهام حتى الآن)."
  else
    echo "⚠️ قاعدة hf_tasks.db موجودة لكن جدول tasks غير موجود."
  fi
fi

echo
echo "=================================================="
echo "✅ تقرير حالة العمال مكتمل (قراءة فقط، بدون أي تعديل على البيانات)"
echo "=================================================="
