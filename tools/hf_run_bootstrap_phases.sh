#!/usr/bin/env bash
# تشغيل كل مراحل الـ Bootstrap الأساسية داخل HyperFFactory (بدون لمس /opt)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_run_bootstrap_phases_${STAMP}.log"

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
log "== HF RUN BOOTSTRAP PHASES (UNIFIED INTERNAL TREE ONLY)"
log "============================================================"
log "ROOT = $ROOT"
log "LOG  = $LOG_FILE"
log

cd "$ROOT"

# تأكيد الهيكل الموحّد (قراءة فقط)
if [[ -x "$ROOT/bin/hf_assert_unified_tree.sh" ]]; then
    log "🔎 فحص سياسة الهيكل الموحّد: bin/hf_assert_unified_tree.sh"
    "$ROOT/bin/hf_assert_unified_tree.sh" || log "⚠️ تحذير من assert_unified_tree (مراجعة لاحقًا)"
fi

log
log "---- المرحلة 1: Bootstrap النواة الموحدة ----"
run_if_exists "$ROOT/tools/hf_bootstrap_unified_core.sh"

log
log "---- المرحلة 2: Lakehouse + Factories ----"
run_if_exists "$ROOT/tools/hf_bootstrap_lakehouse_and_factories.sh"

log
log "---- المرحلة 3: Patterns + Knowledge ----"
run_if_exists "$ROOT/tools/hf_bootstrap_knowledge_and_patterns.sh"

log
log "---- المرحلة 4: Quality + Training Systems ----"
run_if_exists "$ROOT/tools/hf_bootstrap_quality_and_training.sh"

log
log "---- المرحلة 5 (اختيارية): Advanced Infra ----"
run_if_exists "$ROOT/tools/hf_bootstrap_advanced_infra.sh"

log
log "============================================================"
log "انتهى HF RUN BOOTSTRAP PHASES (بدون حذف أي بيانات)."
log "راجع اللوج: $LOG_FILE"
log "============================================================"
