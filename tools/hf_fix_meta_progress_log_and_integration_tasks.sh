#!/usr/bin/env bash
# إصلاح hf_ops_meta.db:
# - توسيع progress_log ليشمل الأعمدة الجديدة (actor, scope, action, details, ts)
# - تحديث مهام integration_smartfriend / integration_ffactory إلى DONE
# - تسجيل إدخالات في progress_log للمرحلتين 3 و 4

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
TS_RAW="$(date +%Y%m%d_%H%M%S)"

META_DB="$HYPER_ROOT/db/meta/hf_ops_meta.db"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_fix_meta_progress_log_and_integration_tasks_${TS_RAW}.log"

mkdir -p "$REPORT_DIR"

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"
}

section() {
  echo "=====================================================" | tee -a "$REPORT"
  echo "$*" | tee -a "$REPORT"
  echo "=====================================================" | tee -a "$REPORT"
}

section "HF Meta Fix – progress_log schema + integration tasks"
log "ROOT   : $HYPER_ROOT"
log "META_DB: $META_DB"
log "REPORT : $REPORT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 غير مثبت – لا يمكن متابعة الإصلاح."
  exit 1
fi

if [[ ! -f "$META_DB" ]]; then
  log "ERROR: قاعدة البيانات غير موجودة: $META_DB"
  exit 1
fi

########################################################
# 1) التأكد من وجود جدول progress_log
########################################################
section "1) Ensure progress_log table exists"

HAS_TABLE="$(sqlite3 "$META_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='progress_log';" || true)"

if [[ -z "$HAS_TABLE" ]]; then
  log "Table progress_log غير موجود – سيتم إنشاؤه بالهيكل الجديد."
  sqlite3 "$META_DB" <<SQL
CREATE TABLE progress_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  scope TEXT,
  action TEXT,
  details TEXT,
  ts TEXT
);
SQL
else
  log "Table progress_log موجود – سيتم فحص الأعمدة وإضافة الناقص فقط."
fi

########################################################
# 2) توسيع progress_log بإضافة الأعمدة الناقصة
########################################################
section "2) Extend progress_log columns if missing"

ensure_column() {
  local col="$1"
  local type="$2"
  # قراءة أسماء الأعمدة الحالية
  local has_col
  has_col="$(sqlite3 "$META_DB" "PRAGMA table_info(progress_log);" | awk -F'|' '{print $2}' | grep -x "$col" || true)"
  if [[ -n "$has_col" ]]; then
    log "  - Column '$col' موجود بالفعل."
  else
    log "  - Adding column '$col' ($type) إلى progress_log..."
    sqlite3 "$META_DB" "ALTER TABLE progress_log ADD COLUMN $col $type;"
  fi
}

ensure_column "actor"   "TEXT"
ensure_column "scope"   "TEXT"
ensure_column "action"  "TEXT"
ensure_column "details" "TEXT"
ensure_column "ts"      "TEXT"

log "Schema progress_log بعد التحديث:"
sqlite3 "$META_DB" "PRAGMA table_info(progress_log);" | tee -a "$REPORT" || true

########################################################
# 3) تحديث المهام integration_smartfriend / integration_ffactory إلى DONE
########################################################
section "3) Update integration_smartfriend / integration_ffactory tasks -> DONE"

# نتأكد أولًا أن جدول tasks موجود
HAS_TASKS="$(sqlite3 "$META_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';" || true)"
if [[ -z "$HAS_TASKS" ]]; then
  log "ERROR: جدول tasks غير موجود – لن نعدّل المهام."
else
  log "تحديث حالة المهام في جدول tasks..."

  sqlite3 "$META_DB" <<SQL
UPDATE tasks
SET status='DONE',
    updated_at='$TS_HUMAN'
WHERE actor='hyper_brain_controller'
  AND scope='integration_smartfriend';

UPDATE tasks
SET status='DONE',
    updated_at='$TS_HUMAN'
WHERE actor='hyper_brain_controller'
  AND scope='integration_ffactory';
SQL

  log "لقطة من المهام بعد التحديث:"
  sqlite3 "$META_DB" "SELECT id, actor, scope, status, priority, title, created_at, updated_at FROM tasks ORDER BY id;" | tee -a "$REPORT" || true
fi

########################################################
# 4) تسجيل إدخالات progress_log للمرحلتين 3 و 4
########################################################
section "4) Insert progress_log entries for Stage3 + Stage4"

sqlite3 "$META_DB" <<SQL
INSERT INTO progress_log (actor, scope, action, details, ts)
VALUES (
  'hyper_brain_controller',
  'integration_smartfriend',
  'stage3_smartfriend_integration',
  'Stage3: health check + hf_health_all + endpoints probe + task marked DONE (schema fixed)',
  '$TS_HUMAN'
);

INSERT INTO progress_log (actor, scope, action, details, ts)
VALUES (
  'hyper_brain_controller',
  'integration_ffactory',
  'stage4_ffactory_integration',
  'Stage4: ffactory presence check + hf_health_all + docker snapshot + task marked DONE (schema fixed)',
  '$TS_HUMAN'
);
SQL

log "لقطة من progress_log (آخر 20 صف تقريبًا):"
sqlite3 "$META_DB" "SELECT id, actor, scope, action, ts FROM progress_log ORDER BY id DESC LIMIT 20;" | tee -a "$REPORT" || true

########################################################
# 5) ملخص
########################################################
section "5) Summary"

log "تم إصلاح progress_log (توسيع الأعمدة) وتحديث مهام integration_smartfriend / integration_ffactory إلى DONE."
log "يمكنك مراجعة التقرير الكامل في: $REPORT"
