#!/usr/bin/env bash
# تقرير مدمج: نواقص الخطة + فجوات الإعداد + نظرة عامة على المهام

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_gap_and_tasks_report_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

run_step() {
    local title="$1"
    local script_path="$2"

    log ""
    log "-------------------- $title --------------------"
    if [ -x "$script_path" ]; then
        log "ℹ️ تشغيل: $script_path"
        "$script_path"
    elif [ -f "$script_path" ]; then
        log "⚠️ الملف موجود لكنه غير قابل للتنفيذ، سيتم تشغيله عبر bash: $script_path"
        bash "$script_path"
    else
        log "❌ لم يتم العثور على السكربت: $script_path"
    fi
}

log "============================================================"
log "== HyperFFactory GAP & TASKS CONSOLIDATED REPORT"
log "============================================================"

cd "$ROOT"

run_step "hf_check_remaining_gaps.sh" "$ROOT/tools/hf_check_remaining_gaps.sh"
run_step "hf_config_gaps_report.sh"   "$ROOT/tools/hf_config_gaps_report.sh"
run_step "hf_tasks_overview.sh"       "$ROOT/tools/hf_tasks_overview.sh"

log ""
log "============================================================"
log "== END GAP & TASKS REPORT"
log "============================================================"
log "📄 التقرير الكامل موجود في:"
log "   $LOG_FILE"
