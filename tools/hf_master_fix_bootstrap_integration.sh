#!/usr/bin/env bash
# HyperFFactory – Master Fix + Bootstrap + Integration + Reports
#
# الاستخدام:
#   ./tools/hf_master_fix_bootstrap_integration.sh
#
# يحترم:
#   - الجذر الرسمي: /root/HyperFFactory
#   - عدم لمس /opt/ffactory إلا عبر سكربتاتك الحالية
#   - عدم حذف أي قاعدة بيانات أو تقارير

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
DB_DIR="$ROOT/db/meta"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_master_fix_bootstrap_integration_${STAMP}.log"

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
        log "⚠️ الملف موجود لكنه غير قابل للتنفيذ: $script (تخطي)"
    else
        log "ℹ️ السكربت غير موجود (تخطي): $script"
    fi
}

log "============================================================"
log "== HF MASTER: FIX + BOOTSTRAP + INTEGRATION + REPORTS"
log "============================================================"
log "ROOT = $ROOT"
log "LOG  = $LOG_FILE"
log

# 0) فحوصات عامة
if [[ ! -d "$ROOT" ]]; then
    log "❌ المسار $ROOT غير موجود – أوقف."
    exit 1
fi

cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
    log "❌ sqlite3 غير متوفر – بعض الخطوات لن تعمل (Meta/Changes)."
fi

# 1) فحص سياسة الهيكل الموحّد (لو متوفر)
if [[ -x "$ROOT/bin/hf_assert_unified_tree.sh" ]]; then
    log "---- 1) فحص سياسة الهيكل الموحّد (Unified Tree Policy) ----"
    "$ROOT/bin/hf_assert_unified_tree.sh" || \
        log "⚠️ تحذير: hf_assert_unified_tree.sh أبلغ عن مشاكل – راجع تقريره."
else
    log "ℹ️ hf_assert_unified_tree.sh غير موجود – تخطي فحص السياسة."
fi

# 2) تفعيل قواعد Meta + hf_changes
log
log "---- 2) تفعيل Meta DBs + hf_changes (دفتر التغييرات) ----"
if [[ -x "$ROOT/tools/hf_apply_meta_and_changes.sh" ]]; then
    "$ROOT/tools/hf_apply_meta_and_changes.sh"
else
    log "⚠️ hf_apply_meta_and_changes.sh غير موجود – لن أستطيع تفعيل Meta بشكل كامل."
fi

# 3) تشغيل Bootstrap الداخلي
log
log "---- 3) تشغيل مراحل الـ Bootstrap داخل HyperFFactory ----"
run_if_exists "$ROOT/tools/hf_run_bootstrap_phases.sh"

# 4) تشغيل الدمج الموحّد مع SmartFriend Suite + FFactory
log
log "---- 4) تشغيل الدمج الموحّد (HyperFFactory + SmartFriend Suite + FFactory) ----"
run_if_exists "$ROOT/tools/hf_run_unified_integration.sh"

# 5) تقارير الحالة والنواقص والمهام
log
log "---- 5) تقارير GAP + STATUS + TASKS ----"
run_if_exists "$ROOT/tools/hf_gap_and_tasks_report.sh"
run_if_exists "$ROOT/tools/hf_full_status_report.sh"
run_if_exists "$ROOT/tools/hf_config_gaps_report.sh"
run_if_exists "$ROOT/tools/hf_tasks_overview.sh"

# 6) تسجيل تشغيل الـ Master في hf_changes (لو متوفر)
if [[ -f "$DB_DIR/hf_changes.db" && $(command -v sqlite3 >/dev/null 2>&1; echo $?) -eq 0 ]]; then
    log "▶ تسجيل تشغيل HF MASTER في hf_changes.db"
    sqlite3 "$DB_DIR/hf_changes.db" <<SQL
INSERT INTO hf_changes (ts, actor, change_type, target, details, meta)
VALUES (
    datetime('now'),
    'hf_master_fix_bootstrap_integration.sh',
    'MASTER_RUN',
    'HyperFFactory',
    'تشغيل سكربت الماستر: تفعيل Meta + Bootstrap + Integration + Reports',
    json_object(
        'log_file', '$LOG_FILE',
        'bootstrap_script', 'tools/hf_run_bootstrap_phases.sh',
        'integration_script', 'tools/hf_run_unified_integration.sh',
        'gap_report', 'tools/hf_gap_and_tasks_report.sh'
    )
);
SQL
    log "✅ تم تسجيل تشغيل الماستر في hf_changes."
else
    log "ℹ️ لم أستطع تسجيل تشغيل الماستر في hf_changes (إما القاعدة غير موجودة أو sqlite3 غير متوفر)."
fi

log
log "============================================================"
log "انتهى HF MASTER FIX + BOOTSTRAP + INTEGRATION."
log "راجع اللوج: $LOG_FILE"
log "============================================================"
