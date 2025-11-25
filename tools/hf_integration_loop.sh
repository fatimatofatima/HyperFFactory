#!/usr/bin/env bash
# HyperFFactory – Integration Continuous Loop
# يشغّل hf_integration_phase_runner.sh بشكل دوري بدون توقف حتى يتم إيقافه يدويًا.
#
# أمثلة:
#   tools/hf_integration_loop.sh --mode=light --interval=600
#   tools/hf_integration_loop.sh --mode=full  --interval=1800

set -Euo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
MAIN_LOG="$LOG_DIR/hf_integration_loop_${STAMP}.log"

exec > >(tee -a "$MAIN_LOG") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

INTERVAL_SECONDS=600
MODE="light"

# قراءة الخيارات
while [[ $# -gt 0 ]]; do
    case "$1" in
        --interval=*)
            INTERVAL_SECONDS="${1#*=}"
            shift
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        *)
            log "WARN خيار غير معروف: $1 (تخطيه)"
            shift
            ;;
    esac
done

log "============================================================"
log "== HF Integration Loop (mode=${MODE}, interval=${INTERVAL_SECONDS}s)"
log "============================================================"
log "ROOT : ${ROOT}"
log "LOG  : ${MAIN_LOG}"
log "لإيقاف الحلقة استخدم Ctrl+C."
log "============================================================"

if [[ ! -x "$ROOT/tools/hf_integration_phase_runner.sh" ]]; then
    log "ERROR tools/hf_integration_phase_runner.sh غير موجود أو غير قابل للتنفيذ."
    exit 1
fi

CYCLE=1
while true; do
    log "---------- بدء دورة رقم ${CYCLE} ----------"
    log "============================================================"

    local_rc=0
    bash -c "cd '${ROOT}' && tools/hf_integration_phase_runner.sh --mode=${MODE}" || local_rc=$?

    if [[ "$local_rc" -eq 0 ]]; then
        log "INFO دورة ${CYCLE} انتهت بدون أخطاء حرجة."
    else
        log "WARN دورة ${CYCLE} انتهت مع أخطاء (rc=${local_rc} – راجع اللوجهات)."
    fi

    log "---------- نهاية دورة رقم ${CYCLE} ----------"
    log "انتظار ${INTERVAL_SECONDS} ثانية قبل الدورة التالية..."
    log "============================================================"

    CYCLE=$((CYCLE + 1))
    sleep "${INTERVAL_SECONDS}"
done

