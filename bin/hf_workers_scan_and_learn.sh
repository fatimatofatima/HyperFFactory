#!/usr/bin/env bash
# HyperFFactory - Workers Scan & Learn
# - بناء خبرة/معرفة للعمّال (actors) من:
#   * hf_quality.db   (quality_checks)
#   * hf_errors.db    (errors)
#   * hf_tasks.db     (tasks) لو موجود
#   * scripts/spiders (السبايدر كعمال من نوع spider)
# - بدون حذف أي بيانات (append فقط)
# - مع تسجيل التقدّم في hf_changes.db عبر hf_progress_log.sh لو موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"
REPORTS_DIR="$ROOT_DIR/reports"

mkdir -p "$DB_DIR" "$REPORTS_DIR"

HF_QUALITY_DB="$DB_DIR/hf_quality.db"
HF_ERRORS_DB="$DB_DIR/hf_errors.db"
HF_TASKS_DB="$DB_DIR/hf_tasks.db"
HF_LEARNING_DB="$DB_DIR/hf_learning.db"

SPIDERS_DIR="$ROOT_DIR/scripts/spiders"

PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
NOW_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
NOW_COMPACT="$(date '+%Y%m%d_%H%M%S')"

REPORT_FILE="$REPORTS_DIR/hf_workers_scan_${NOW_COMPACT}.log"

log() {
  echo "$@" | tee -a "$REPORT_FILE"
}

log "=================================================="
log "👷 HyperFFactory – Workers Scan & Learn"
log "📍 Root : $ROOT_DIR"
log "📂 DBs  : $DB_DIR"
log "📄 Report: $REPORT_FILE"
log "⏱️ Time : $NOW_HUMAN"
log "=================================================="

if [[ -x "$PROGRESS_LOG" ]]; then
  "$PROGRESS_LOG" "hf_workers_scan_and_learn" "INFO" "start scan workers → learning" || true
fi

# 1) ضمان وجود جدول learning
log "🔧 التأكد من وجود جدول learning في hf_learning.db"

sqlite3 "$HF_LEARNING_DB" <<SQL
CREATE TABLE IF NOT EXISTS learning (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source     TEXT NOT NULL,
  pattern    TEXT NOT NULL,
  outcome    TEXT,
  confidence REAL,
  ts         TEXT NOT NULL
);
SQL

# 2) من جودة العمال (hf_quality.db / quality_checks)
if [[ -f "$HF_QUALITY_DB" ]]; then
  log "📊 استيراد جودة العمال من hf_quality.db → learning"

  while IFS='|' read -r actor checks pass_cnt fail_cnt warn_cnt first_ts last_ts avg_score; do
    [[ -z "\$actor" ]] && continue

    outcome="worker_quality: checks=\$checks pass=\$pass_cnt fail=\$fail_cnt warn=\$warn_cnt first_ts=\$first_ts last_ts=\$last_ts avg_score=\$avg_score"
    confidence="\$avg_score"

    sqlite3 "$HF_LEARNING_DB" <<SQL
INSERT INTO learning (source,pattern,outcome,confidence,ts)
VALUES (
  'hf_workers_scan',
  'worker:\$actor',
  '\$outcome',
  \$confidence,
  '$NOW_HUMAN'
);
SQL

  done < <(
    sqlite3 "$HF_QUALITY_DB" "
      SELECT actor,
             COUNT(*) AS checks,
             SUM(CASE WHEN result='PASS' THEN 1 ELSE 0 END) AS pass_cnt,
             SUM(CASE WHEN result='FAIL' THEN 1 ELSE 0 END) AS fail_cnt,
             SUM(CASE WHEN result='WARN' THEN 1 ELSE 0 END) AS warn_cnt,
             MIN(ts) AS first_ts,
             MAX(ts) AS last_ts,
             printf('%.1f',AVG(score)) AS avg_score
      FROM quality_checks
      GROUP BY actor
      ORDER BY actor;
    "
  )

else
  log "⚠️ لا يوجد $HF_QUALITY_DB - تخطي جزء الجودة"
fi

# 3) من أخطاء العمال (hf_errors.db / errors)
if [[ -f "$HF_ERRORS_DB" ]]; then
  log "🚨 استيراد أخطاء العمال من hf_errors.db → learning"

  while IFS='|' read -r actor errors_cnt severities first_ts last_ts; do
    [[ -z "\$actor" ]] && continue

    outcome="worker_errors: count=\$errors_cnt severities=\$severities first_ts=\$first_ts last_ts=\$last_ts"

    sqlite3 "$HF_LEARNING_DB" <<SQL
INSERT INTO learning (source,pattern,outcome,confidence,ts)
VALUES (
  'hf_workers_scan',
  'worker:\$actor',
  '\$outcome',
  0.0,
  '$NOW_HUMAN'
);
SQL

  done < <(
    sqlite3 "$HF_ERRORS_DB" "
      SELECT actor,
             COUNT(*) AS errors_cnt,
             GROUP_CONCAT(DISTINCT severity) AS severities,
             MIN(ts) AS first_ts,
             MAX(ts) AS last_ts
      FROM errors
      GROUP BY actor
      ORDER BY actor;
    "
  )

else
  log "⚠️ لا يوجد $HF_ERRORS_DB - تخطي جزء الأخطاء"
fi

# 4) من المهام (hf_tasks.db / tasks) – لو الجدول موجود
if [[ -f "$HF_TASKS_DB" ]]; then
  log "📝 استيراد حالة المهام من hf_tasks.db → learning (لو جدول tasks موجود)"

  # نتحقق أولاً أن جدول tasks موجود، لو مش موجود نتخطى بهدوء
  if sqlite3 "$HF_TASKS_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';" | grep -q tasks; then
    while IFS='|' read -r actor planned running done_cnt failed_cnt skipped_cnt; do
      [[ -z "\$actor" ]] && continue

      outcome="worker_tasks: planned=\$planned running=\$running done=\$done_cnt failed=\$failed_cnt skipped=\$skipped_cnt"

      sqlite3 "$HF_LEARNING_DB" <<SQL
INSERT INTO learning (source,pattern,outcome,confidence,ts)
VALUES (
  'hf_workers_scan',
  'worker:\$actor',
  '\$outcome',
  0.0,
  '$NOW_HUMAN'
);
SQL

    done < <(
      sqlite3 "$HF_TASKS_DB" "
        SELECT actor,
               SUM(CASE WHEN status='PLANNED' THEN 1 ELSE 0 END) AS planned,
               SUM(CASE WHEN status='RUNNING' THEN 1 ELSE 0 END) AS running,
               SUM(CASE WHEN status='DONE'    THEN 1 ELSE 0 END) AS done_cnt,
               SUM(CASE WHEN status='FAILED'  THEN 1 ELSE 0 END) AS failed_cnt,
               SUM(CASE WHEN status='SKIPPED' THEN 1 ELSE 0 END) AS skipped_cnt
        FROM tasks
        GROUP BY actor
        ORDER BY actor;
      "
    )
  else
    log "⚠️ جدول tasks غير موجود داخل hf_tasks.db - تخطي جزء المهام"
  fi
else
  log "⚠️ لا يوجد $HF_TASKS_DB - تخطي جزء المهام"
fi

# 5) سبايدر (scripts/spiders)
if [[ -d "$SPIDERS_DIR" ]]; then
  log "🕷️ استيراد سبايدر من $SPIDERS_DIR → learning"

  while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    outcome="spider_script: path=$file"

    sqlite3 "$HF_LEARNING_DB" <<SQL
INSERT INTO learning (source,pattern,outcome,confidence,ts)
VALUES (
  'hf_workers_scan',
  'spider:$name',
  '$outcome',
  0.8,
  '$NOW_HUMAN'
);
SQL

  done < <(find "$SPIDERS_DIR" -maxdepth 1 -type f -print0)

else
  log "⚠️ لا يوجد مجلد $SPIDERS_DIR - تخطي spiders"
fi

# 6) ملخّص نهائي
TOTAL_ROWS="$(sqlite3 "$HF_LEARNING_DB" "SELECT COUNT(*) FROM learning;")"
log "=================================================="
log "✅ تم تحديث جدول learning في hf_learning.db"
log "📊 إجمالي السجلات الآن: $TOTAL_ROWS"
log "=================================================="

if [[ -x "$PROGRESS_LOG" ]]; then
  "$PROGRESS_LOG" "hf_workers_scan_and_learn" "INFO" "workers scan complete, learning_rows=$TOTAL_ROWS" || true
fi

exit 0
