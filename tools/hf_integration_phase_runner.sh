#!/usr/bin/env bash
# HyperFFactory – Integration Phase Runner
# دورة واحدة تجمع مراحل:
#  - Bootstrap Phases
#  - Meta Systems
#  - Unified Integration
#  - (اختياري في وضع full) فهرس داخلي + master fix/report

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_integration_phase_runner_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

MODE="light"

# قراءة خيارات السطر
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        *)
            log "⚠️ خيار غير معروف: $1 (تخطيه)"
            shift
            ;;
    esac
done

log "============================================================"
log "== HF Integration Phase Runner (mode=${MODE})"
log "============================================================"
log "ROOT : ${ROOT}"
log "LOG  : ${LOG_FILE}"

cd "$ROOT"

# دالة تنفيذ خطوة مع لوج وفشل غير قاتل
step() {
    local title="$1"; shift
    log "------------------------------------------------------------"
    log "---- START STEP: ${title} ----"

    if [[ $# -eq 0 ]]; then
        log "⚠️ لا يوجد أمر مُعطى لهذه الخطوة (skip)"
        return 0
    fi

    # إن كان أول وسيط مسار سكربت، نتأكد من وجوده وصلاحيته
    if [[ "$1" == /* || "$1" == ./* || "$1" == */* ]]; then
        if [[ ! -x "$1" ]]; then
            log "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $1 (skip)"
            return 0
        fi
    fi

    if "$@"; then
        log "✅ DONE STEP:  ${title}"
    else
        log "⚠️ FAILED STEP: ${title} (مواصلة بقية الخطوات)"
    fi
}

# 0) فحص أساسي للمسار والأدوات
step "0) فحص أساسي للمسار والأدوات" bash -lc "
    cd \"$ROOT\" || exit 1
    echo \"ROOT OK: $(pwd)\"
    if command -v sqlite3 >/dev/null 2>&1; then
        echo \"sqlite3: OK\"
    else
        echo \"⚠️ sqlite3 غير متوفر\"
    fi
    if command -v docker >/dev/null 2>&1; then
        echo \"docker: OK\"
    else
        echo \"⚠️ docker غير متوفر أو غير في PATH\"
    fi
"

# 1) Bootstrap Phases
step "1) HF RUN BOOTSTRAP PHASES" "$ROOT/tools/hf_run_bootstrap_phases.sh"

# 2) Meta Systems (Tasks / Quality / Learning / Errors)
step "2) HF RUN META SYSTEMS" "$ROOT/tools/hf_run_meta_systems.sh"

# 3) Unified Integration (Suite + ffactory + Telegram snapshot)
step "3) HF RUN UNIFIED INTEGRATION" "$ROOT/tools/hf_run_unified_integration.sh"

# 4) فهرس داخلي + Master Fix/Report (في وضع full فقط)
if [[ "$MODE" == "full" ]]; then
    step "4) Build Internal Files Index (hf_build_internal_index.sh إن وجد)" \
         "$ROOT/tools/hf_build_internal_index.sh"

    step "5) Master Fix & Report (hf_master_fix_and_report.sh إن وجد)" \
         "$ROOT/tools/hf_master_fix_and_report.sh"
fi

log "============================================================"
log "== HF Integration Phase Runner finished (mode=${MODE})"
log "== راجع اللوج: ${LOG_FILE}"
log "============================================================"
