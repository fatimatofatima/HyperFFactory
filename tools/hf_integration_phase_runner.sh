#!/usr/bin/env bash
# HyperFFactory – Integration Phase Runner
# يجمع مراحل التكامل/الدمج في دورة واحدة.
#
# أوضاع التشغيل:
#   --mode=light  : خطوات أساسية (meta + unified integration)
#   --mode=full   : كل المراحل (bootstrap + meta + unified + index)
#
# ملاحظات:
# - لا يخرج من أول خطأ، بل يسجل الخطأ ويكمل باقي الخطوات.
# - لا يلمس أي شيء خارج /root/HyperFFactory و /opt/smartfriend-suite و /opt/ffactory (قراءة فقط).

set -Euo pipefail

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

# قراءة خيارات التشغيل
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        *)
            log "WARN  خيار غير معروف: $1 (تخطيه)"
            shift
            ;;
    esac
done

log "============================================================"
log "== HF Integration Phase Runner (mode=${MODE})"
log "============================================================"
log "ROOT : ${ROOT}"
log "LOG  : ${LOG_FILE}"
log "============================================================"

# خطوة مساعدة لتشغيل أمر مع عنوان
run_step() {
    local title="$1"
    local cmd="$2"

    log "---- START STEP: ${title} ----"
    local rc=0
    # تشغيل الأمر داخل subshell حتى لا يكسّر البيئة العامة
    bash -c "cd '${ROOT}' && ${cmd}" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        log "DONE STEP:  ${title}"
    else
        log "WARN FAILED STEP: ${title} (rc=${rc} – سيتم الاستمرار)"
    fi
    log "-----------------------------"
}

# 0) فحص أساسي للمسار والأدوات
run_step "0) فحص أساسي للمسار والأدوات" '
    if [[ ! -d "$ROOT" ]]; then
        echo "ERROR ROOT غير موجود: $ROOT"
        exit 1
    fi
    cd "$ROOT"
    command -v sqlite3 >/dev/null 2>&1 || echo "INFO sqlite3 غير متوفر (بعض المراحل قد تعتمد عليه)"
'

# 1) Bootstrap phases (في وضع full فقط – آمن/Idempotent)
if [[ "$MODE" == "full" ]]; then
    if [[ -x "$ROOT/tools/hf_run_bootstrap_phases.sh" ]]; then
        run_step "1) Bootstrap phases (hf_run_bootstrap_phases.sh)" \
                 "tools/hf_run_bootstrap_phases.sh"
    else
        log "INFO تخطي bootstrap: tools/hf_run_bootstrap_phases.sh غير موجود/غير قابل للتنفيذ."
    fi
fi

# 2) Meta systems (tasks / quality / learning / errors)
if [[ -x "$ROOT/tools/hf_run_meta_systems.sh" ]]; then
    run_step "2) Meta systems (hf_run_meta_systems.sh)" \
             "tools/hf_run_meta_systems.sh"
else
    log "INFO تخطي meta systems: tools/hf_run_meta_systems.sh غير موجود/غير قابل للتنفيذ."
fi

# 3) Unified integration (SmartFriend + FFactory snapshot)
if [[ -x "$ROOT/tools/hf_run_unified_integration.sh" ]]; then
    run_step "3) Unified integration (hf_run_unified_integration.sh)" \
             "tools/hf_run_unified_integration.sh"
elif [[ -x "$ROOT/tools/hf_ops_start_suite_and_ffactory.sh" ]]; then
    # نسخة أقدم من سكربت التكامل
    run_step "3) Unified integration (hf_ops_start_suite_and_ffactory.sh)" \
             "tools/hf_ops_start_suite_and_ffactory.sh"
else
    log "INFO تخطي unified integration: لا يوجد hf_run_unified_integration.sh ولا hf_ops_start_suite_and_ffactory.sh."
fi

# 4) Internal files index (اختياري – لا نفشل الدورة لو غاب)
if [[ "$MODE" == "full" ]]; then
    if [[ -x "$ROOT/tools/hf_build_internal_index.sh" ]]; then
        run_step "4) Internal files index (hf_build_internal_index.sh)" \
                 "tools/hf_build_internal_index.sh"
    else
        log "INFO تخطي index: tools/hf_build_internal_index.sh غير موجود/غير قابل للتنفيذ."
    fi
fi

log "============================================================"
log "انتهت دورة HF Integration Phase Runner (mode=${MODE})."
log "راجع اللوج عند الحاجة:"
log "  ${LOG_FILE}"
log "============================================================"

exit 0
