#!/usr/bin/env bash
# HyperFFactory – حلقة تكامل/دمج مستمر بناءً على سكربت الماستر الحالي
# يعتمد على:
#   tools/hf_master_fix_bootstrap_integration.sh
# ويعمل في Loop مع فاصل زمني ثابت.

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
MAIN_LOG="$LOG_DIR/hf_auto_integration_loop_${STAMP}.log"

exec > >(tee -a "$MAIN_LOG") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

# الفاصل الزمني بين كل دورة تكامل (ثواني)
# يمكن تغييره من الخارج:
#   HF_AUTO_INTERVAL_SECONDS=600 ./tools/hf_auto_integration_loop.sh
INTERVAL_SECONDS="${HF_AUTO_INTERVAL_SECONDS:-300}"

# تأكيد المسار
if [[ ! -d "$ROOT" ]]; then
    log "❌ ROOT غير موجود: $ROOT"
    exit 1
fi
cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
    log "⚠️ sqlite3 غير متوفر؛ سيتم العمل بدون مقاييس للمهام."
fi

# قفل بسيط لمنع تشغيل أكثر من حلقة في نفس الوقت
LOCK_FILE="/tmp/hf_auto_integration_loop.lock"
exec 9>"$LOCK_FILE" || {
    log "⚠️ تعذر فتح ملف القفل: $LOCK_FILE"
    exit 1
}
if ! flock -n 9; then
    log "⚠️ توجد حلقة تكامل أخرى تعمل بالفعل (lock: $LOCK_FILE) – خروج."
    exit 0
fi

log "============================================================"
log "== HF AUTO INTEGRATION LOOP (Continuous)"
log "============================================================"
log "ROOT       = $ROOT"
log "LOG        = $MAIN_LOG"
log "INTERVAL   = ${INTERVAL_SECONDS}s"
log "LOCK_FILE  = $LOCK_FILE"
log "============================================================"

progress_snapshot() {
    local db="$ROOT/db/meta/hf_ops_meta.db"
    if [[ -f "$db" && -x "$(command -v sqlite3 || echo /bin/false)" ]]; then
        local row
        row="$(sqlite3 "$db" "SELECT
            IFNULL(SUM(status='PLANNED'),0),
            IFNULL(SUM(status='RUNNING'),0),
            IFNULL(SUM(status='DONE'),0)
          FROM tasks;
        " 2>/dev/null || true)"
        if [[ -n "$row" ]]; then
            local planned running done
            IFS='|' read -r planned running done <<<"$row"
            log "📊 وضع المهام: PLANNED=$planned RUNNING=$running DONE=$done"
        else
            log "ℹ️ تعذر قراءة عدّادات المهام من hf_ops_meta.tasks (ربما لا توجد جداول بعد)."
        fi
    else
        log "ℹ️ لا يمكن قراءة hf_ops_meta.db (غير موجود أو sqlite3 غير متوفر)."
    fi
}

while true; do
    log "---------- دورة تكامل جديدة ----------"

    if [[ -x "$ROOT/tools/hf_master_fix_bootstrap_integration.sh" ]]; then
        "$ROOT/tools/hf_master_fix_bootstrap_integration.sh" || \
            log "⚠️ تحذير: سكربت الماستر أنهى بدلالات خطأ (راجع لوجه الخاصة به)."
    else
        log "❌ سكربت الماستر غير موجود أو غير قابل للتنفيذ: tools/hf_master_fix_bootstrap_integration.sh"
        log "   إيقاف الحلقة."
        exit 1
    fi

    # لقطة تقدم (PLANNED/RUNNING/DONE)
    progress_snapshot

    log "⏳ انتظار ${INTERVAL_SECONDS} ثانية قبل دورة التكامل التالية..."
    sleep "$INTERVAL_SECONDS"
done
