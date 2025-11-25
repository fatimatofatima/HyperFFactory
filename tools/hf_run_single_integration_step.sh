#!/usr/bin/env bash
# HyperFFactory – خطوة تكامل/دمج واحدة + تقرير سريع عن حالة المهام

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_run_single_integration_step_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

log "============================================================"
log "== HF SINGLE INTEGRATION STEP"
log "============================================================"
log "ROOT = $ROOT"
log "LOG  = $LOG_FILE"
log "============================================================"

if [[ ! -d "$ROOT" ]]; then
    log "❌ ROOT غير موجود: $ROOT"
    exit 1
fi
cd "$ROOT"

if [[ ! -x "$ROOT/tools/hf_master_fix_bootstrap_integration.sh" ]]; then
    log "❌ سكربت الماستر غير موجود أو غير قابل للتنفيذ: tools/hf_master_fix_bootstrap_integration.sh"
    exit 1
fi

log "▶ تشغيل سكربت الماستر: hf_master_fix_bootstrap_integration.sh"
"$ROOT/tools/hf_master_fix_bootstrap_integration.sh" || \
    log "⚠️ تحذير: سكربت الماستر أنهى بخطأ (راجع لوجه الخاصة)."

DB="$ROOT/db/meta/hf_ops_meta.db"
if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$DB" ]]; then
    log "------------------------------------------------------------"
    log "📊 Snapshot من جدول المهام (hf_ops_meta.tasks)"
    log "------------------------------------------------------------"
    sqlite3 "$DB" <<SQL
.headers on
.mode column

SELECT status, COUNT(*) AS cnt
FROM tasks
GROUP BY status
ORDER BY 
  CASE status
    WHEN 'PLANNED' THEN 1
    WHEN 'RUNNING' THEN 2
    WHEN 'DONE'    THEN 3
    ELSE 4
  END;
SQL
else
    log "ℹ️ لا يمكن قراءة hf_ops_meta.tasks (hf_ops_meta.db غير موجود أو sqlite3 غير متوفر)."
fi

log "============================================================"
log "انتهت خطوة التكامل الواحدة. راجع اللوج عند الحاجة:"
log "  $LOG_FILE"
log "============================================================"
