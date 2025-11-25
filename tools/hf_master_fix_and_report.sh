#!/usr/bin/env bash
# HyperFFactory – Master Fix & Report
# سكربت رئيسي لإكمال النواقص الأساسية + تقارير حالة ونواقص ومهام.
#
# خواص:
# - الوضع الافتراضي: DRY-RUN (لا يغيّر شيء، فقط يستدعي السكربتات بالفحص).
# - مع --apply: يفعّل سكربتات الإصلاح (hf_fix_all_gaps_stage2.sh) + يسجّل في hf_changes.db.
#
# يحترم:
# - الجذر الرسمي: /root/HyperFFactory
# - عدم لمس /opt/ffactory
# - عدم حذف أي DB أو تقرير
# - عدم تشغيل/إيقاف خدمات (يكتفي بالقراءة من سكربتاتك الحالية).

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_master_fix_and_report_${STAMP}.log"

MODE="dry-run"
if [[ "${1:-}" == "--apply" ]]; then
    MODE="apply"
fi

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s [%s] %s\n' "$(date -Iseconds)" "$MODE" "$*"
}

SECTION() {
    echo
    echo "============================================================"
    echo "== $*"
    echo "============================================================"
}

# تسجيل في hf_changes.db لو موجود (بدون تعقيد كبير)
record_change() {
    local change_type="$1"
    local target="$2"
    local details="$3"

    local DB="$ROOT/db/meta/hf_changes.db"

    if [[ ! -f "$DB" ]]; then
        return 0
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        return 0
    fi

    # منع مشاكل بسيطة في علامات الاقتباس
    local ts actor
    ts="$(date -Iseconds)"
    actor="hf_master_fix_and_report.sh"
    # ملاحظة: نفترض عدم وجود ' في القيم – لو موجودة سيتم تجاهل الإدخال بهدوء
    sqlite3 "$DB" 2>/dev/null <<SQL
INSERT INTO hf_changes (ts, actor, change_type, target, details, meta)
VALUES ('$ts', '$actor', '$change_type', '$target', '$details', NULL);
SQL
}

run_script_if_exists() {
    local title="$1"
    local path="$2"
    shift 2
    local args=("$@")

    SECTION "$title"
    if [[ -x "$path" ]]; then
        log "تشغيل: $path ${args[*]}"
        record_change "RUN" "$path" "$title"
        if ! "$path" "${args[@]}"; then
            log "⚠️ السكربت $path أنهى بخطأ (تحذير، نكمل باقي الخطوات)."
            record_change "ERROR" "$path" "exit_nonzero"
        else
            log "✅ السكربت $path أنهى بنجاح."
        fi
    elif [[ -f "$path" ]]; then
        log "⚠️ الملف موجود لكنه غير قابل للتنفيذ: $path"
    else
        log "ℹ️ السكربت غير موجود (تخطي): $path"
    fi
}

#--------------------------- 0) فحوصات عامة ---------------------------#

SECTION "0) فحوصات عامة للمسار والأدوات"

if [[ "$(pwd)" != "$ROOT" ]]; then
    log "ℹ️ المسار الحالي: $(pwd) – التبديل إلى $ROOT"
    cd "$ROOT" || { log "❌ تعذّر الدخول إلى $ROOT"; exit 1; }
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    log "ℹ️ داخل مستودع Git (فرع: $CURRENT_BRANCH) – للمعلومة فقط."
else
    log "ℹ️ هذا المجلد لا يُعامل كـ Git الآن (لا مشكلة للسكربت)."
fi

if command -v sqlite3 >/dev/null 2>&1; then
    log "ℹ️ sqlite3 متوفر."
else
    log "⚠️ sqlite3 غير متوفر – لن تُطبّق سكربتات SQL ولن يتم التسجيل في hf_changes.db."
fi

record_change "INIT" "hf_master_fix_and_report" "start $MODE"

#--------------------------- 1) فحص سياسة الهيكل الموحّد ---------------------------#

SECTION "1) فحص سياسة الهيكل الموحّد (Unified Tree Policy)"

ASSERT_SCRIPT="$ROOT/bin/hf_assert_unified_tree.sh"
if [[ -x "$ASSERT_SCRIPT" ]]; then
    log "تشغيل حارس الشجرة: $ASSERT_SCRIPT"
    record_change "CHECK" "hf_assert_unified_tree.sh" "unified_tree_policy"
    if ! "$ASSERT_SCRIPT"; then
        log "⚠️ hf_assert_unified_tree.sh أبلغ عن مخالفات – راجع تقاريره في reports/."
        record_change "ERROR" "hf_assert_unified_tree.sh" "policy_violation"
    else
        log "✅ سياسة الهيكل الموحّد تبدو سليمة حسب hf_assert_unified_tree.sh."
    fi
else
    log "ℹ️ hf_assert_unified_tree.sh غير موجود أو غير قابل للتنفيذ – تخطي فحص الشجرة."
fi

#--------------------------- 2) إكمال نواقص Meta DBs (hf_fix_all_gaps_stage2) ---------------------------#

SECTION "2) إكمال نواقص الـ Meta DBs (hf_fix_all_gaps_stage2)"

FIX_STAGE2="$ROOT/tools/hf_fix_all_gaps_stage2.sh"
if [[ -x "$FIX_STAGE2" ]]; then
    if [[ "$MODE" == "dry-run" ]]; then
        log "DRY-RUN: تشغيل $FIX_STAGE2 في وضع dry-run (بدون --apply)."
        record_change "CHECK" "hf_fix_all_gaps_stage2.sh" "dry-run"
        "$FIX_STAGE2" || log "⚠️ hf_fix_all_gaps_stage2.sh (dry-run) أنهى بخطأ."
    else
        log "EXEC: تشغيل $FIX_STAGE2 --apply (إنشاء/تحديث Meta DBs + فحص SmartFriend Suite)."
        record_change "FIX" "hf_fix_all_gaps_stage2.sh" "apply_meta_dbs"
        if ! "$FIX_STAGE2" --apply; then
            log "⚠️ hf_fix_all_gaps_stage2.sh --apply أنهى بخطأ – راجع لوج السكربت."
            record_change "ERROR" "hf_fix_all_gaps_stage2.sh" "apply_failed"
        else
            log "✅ hf_fix_all_gaps_stage2.sh --apply اكتمل بنجاح."
        fi
    fi
else
    log "ℹ️ hf_fix_all_gaps_stage2.sh غير موجود أو غير قابل للتنفيذ – تخطي هذه المرحلة."
fi

#--------------------------- 3) تقارير الحالة العامة (Full Status) ---------------------------#

run_script_if_exists \
  "3) تقرير حالة كامل (hf_full_status_report.sh)" \
  "$ROOT/tools/hf_full_status_report.sh"

#--------------------------- 4) تقرير النواقص والمهام (Gaps & Tasks) ---------------------------#

run_script_if_exists \
  "4) تقرير النواقص + نظرة على المهام (hf_gap_and_tasks_report.sh)" \
  "$ROOT/tools/hf_gap_and_tasks_report.sh"

#--------------------------- 5) ملخص نهائي ---------------------------#

SECTION "5) ملخص التنفيذ"

log "📄 ملف تقرير السكربت الرئيسي: $LOG_FILE"
record_change "DONE" "hf_master_fix_and_report" "finished $MODE"

echo
echo "============================================================"
echo "تم إنهاء hf_master_fix_and_report.sh في وضع: $MODE"
echo "راجع اللوج:"
echo "  $LOG_FILE"
echo "============================================================"
