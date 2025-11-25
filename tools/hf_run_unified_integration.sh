#!/usr/bin/env bash
# دمج وتشغيل موحّد: HyperFFactory + SmartFriend Suite + FFactory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_run_unified_integration_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

run_if_exists() {
    local script="$1"
    if [[ -x "$script" ]]; then
        log "▶ تشغيل: $script"
        "$script"
        log "✅ انتهى بنجاح: $script"
    elif [[ -f "$script" ]]; then
        log "⚠️ موجود لكنه غير قابل للتنفيذ: $script (تخطي)"
    else
        log "ℹ️ غير موجود (تخطي): $script"
    fi
}

log "============================================================"
log "== HF RUN UNIFIED INTEGRATION (SUITE + FFACTORY)"
log "============================================================"
log "ROOT = $ROOT"
log "LOG  = $LOG_FILE"
log

cd "$ROOT"

log
log "---- 1) فحص وتشغيل SmartFriend Suite (دكتور السيوت) ----"
run_if_exists "$ROOT/tools/hf_smartfriend_suite_doctor.sh"

log
log "---- 2) تشغيل موحّد للسيوت + ffactory (إن وُجدت سكربتات الدمج) ----"
run_if_exists "$ROOT/tools/hf_ops_start_suite_and_ffactory.sh"
run_if_exists "$ROOT/tools/hf_start_smartfriend_and_ffactory.sh"
run_if_exists "$ROOT/tools/hf_patch_start_ffactory_core.sh"

log
log "---- 3) أدوات ffactory stack (Docker) من داخل HyperFFactory ----"
run_if_exists "$ROOT/collected_scripts/sh_scripts/ffactory_stack.sh"
run_if_exists "$ROOT/collected_scripts/sh_scripts/ffactory_docker_tool.sh"
run_if_exists "$ROOT/collected_scripts/sh_scripts/ffactory_fix_core_service.sh"

log
log "============================================================"
log "انتهى HF RUN UNIFIED INTEGRATION بدون حذف أي بيانات."
log "راجع اللوج: $LOG_FILE"
log "============================================================"
