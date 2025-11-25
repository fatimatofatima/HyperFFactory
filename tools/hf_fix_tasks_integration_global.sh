#!/usr/bin/env bash
# Fix integration tasks (integration_smartfriend / integration_ffactory)
# في كل قواعد البيانات الموجودة تحت db/meta/*.db
# بدون لمس ffactory أو smartfriend أو أي مشروع خارجي.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
TS_RAW="$(date +%Y%m%d_%H%M%S)"

META_DIR="$HYPER_ROOT/db/meta"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_fix_tasks_integration_global_${TS_RAW}.log"

mkdir -p "$REPORT_DIR"

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"
}

section() {
  echo "=====================================================" | tee -a "$REPORT"
  echo "$*" | tee -a "$REPORT"
  echo "=====================================================" | tee -a "$REPORT"
}

section "HF Global Fix – integration_smartfriend / integration_ffactory tasks"
log "ROOT     : $HYPER_ROOT"
log "META_DIR : $META_DIR"
log "REPORT   : $REPORT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 غير مثبت – لا يمكن متابعة الإصلاح."
  exit 1
fi

if [[ ! -d "$META_DIR" ]]; then
  log "ERROR: المجلد غير موجود: $META_DIR"
  exit 1
fi

shopt -s nullglob
DB_LIST=( "$META_DIR"/*.db )

if (( ${#DB_LIST[@]} == 0 )); then
  log "لا توجد أي ملفات .db داخل $META_DIR – لا شيء لعمله."
  exit 0
fi

section "1) Scan db/meta/*.db for tasks table and integration_* rows"

for DB in "${DB_LIST[@]}"; do
  log "--- DB: $DB ---"

  HAS_TASKS="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';" || true)"
  if [[ -z "$HAS_TASKS" ]]; then
    log "  -> لا يوجد جدول tasks في هذا DB – تخطي."
    continue
  fi

  log "  -> جدول tasks موجود – فحص المهام الخاصة بالتكامل قبل التعديل:"
  sqlite3 "$DB" "
    SELECT id, actor, scope, status, priority, title, created_at, updated_at
    FROM tasks
    WHERE actor='hyper_brain_controller'
      AND scope IN ('integration_smartfriend','integration_ffactory')
    ORDER BY id;
  " | tee -a "$REPORT" || true

  log "  -> تحديث حالة المهام integration_smartfriend / integration_ffactory إلى DONE (إن وجدت)..."
  sqlite3 "$DB" <<SQL
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

  log "  -> لقطة بعد التحديث:"
  sqlite3 "$DB" "
    SELECT id, actor, scope, status, priority, title, created_at, updated_at
    FROM tasks
    WHERE actor='hyper_brain_controller'
      AND scope IN ('integration_smartfriend','integration_ffactory')
    ORDER BY id;
  " | tee -a "$REPORT" || true
done

section "2) Summary"
log "تم تنفيذ محاولة توحيد حالة مهام integration_smartfriend / integration_ffactory في كل قواعد db/meta/*.db."
log "يمكنك مراجعة التقرير الكامل في: $REPORT"
