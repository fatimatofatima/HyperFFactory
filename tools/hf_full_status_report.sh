#!/usr/bin/env bash
# تقرير شامل لحالة HyperFFactory + SmartFriend Suite + Git + الخدمات

set -Eeuo pipefail

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hf_full_status_${TIMESTAMP}.log"

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

SECTION() {
    echo | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
    echo "== $*" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
}

run_if_exists() {
    local label="$1"
    shift
    local cmd=("$@")

    if command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]]; then
        SECTION "$label"
        log "ℹ️ تشغيل: ${cmd[*]}"
        "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE" || {
            log "⚠️ الأمر فشل (غير قاتل): ${cmd[*]}"
        }
    else
        SECTION "$label"
        log "⚠️ الأمر أو السكربت غير موجود: ${cmd[0]}"
    fi
}

main() {
    SECTION "0) معلومات عامة عن المستودع والمسار الحالي"
    pwd | tee -a "$LOG_FILE"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWN")
        log "✅ داخل مستودع Git، الفرع الحالي: $BRANCH"
    else
        log "❌ هذا المجلد ليس مستودع Git"
    fi

    SECTION "1) حالة Git السريعة"
    {
        echo "### git remote -v"
        git remote -v || echo "git remote فشل"

        echo
        echo "### git status --short"
        git status --short || echo "git status فشل"

        echo
        echo "### آخر 3 commits"
        git log -3 --oneline || echo "git log فشل"
    } | tee -a "$LOG_FILE"

    SECTION "2) البحث عن ملفات كبيرة (أكبر من 50MB) قريبة"
    {
        if command -v find >/dev/null 2>&1; then
            find . -type f -size +50M -maxdepth 5 -print 2>/dev/null || true
        else
            echo "find غير متوفر"
        fi
    } | tee -a "$LOG_FILE"

    SECTION "3) فحص وجود structure.txt وحجمه إن وجد"
    if [ -f "structure.txt" ]; then
        log "⚠️ الملف structure.txt موجود داخل المستودع (انتبه لمشكلة GitHub)."
        if command -v du >/dev/null 2>&1; then
            du -h structure.txt | tee -a "$LOG_FILE"
        else
            ls -lh structure.txt | tee -a "$LOG_FILE"
        fi
    else
        log "✅ لا يوجد structure.txt في المسار الجذري للمستودع."
    fi

    SECTION "4) فحص المجلدات الأساسية في HyperFFactory"
    for d in "config" "tools" "collected_scripts" "factories" "patterns_system" "temporal_memory" "integration_hub" "quality_system" "ops" "sql" "plans"; do
        if [ -d "$d" ]; then
            log "✅ موجود: $d/"
        else
            log "⚠️ غير موجود: $d/ (قد يكون مفقود أو لم يُنشأ بعد)"
        fi
    done

    SECTION "5) ملخص ملفات خطة التنفيذ HF_EXEC_PLAN"
    if [ -f "plans/HF_EXEC_PLAN.tsv" ]; then
        log "✅ الملف plans/HF_EXEC_PLAN.tsv موجود."
        head -n 10 plans/HF_EXEC_PLAN.tsv | tee -a "$LOG_FILE" || true
    else
        log "⚠️ الملف plans/HF_EXEC_PLAN.tsv غير موجود."
    fi

    # تشغيل أدوات تشخيص موجودة لو متاحة

    # 6) حالة مستودع HyperFFactory (لو عندك سكربت repo_status)
    if [ -x "tools/hf_repo_status.sh" ]; then
        run_if_exists "6) تقرير hf_repo_status.sh" "tools/hf_repo_status.sh"
    else
        SECTION "6) تقرير hf_repo_status.sh"
        log "ℹ️ tools/hf_repo_status.sh غير موجود أو غير تنفيذي، تخطي."
    fi

    # 7) دكتور السيوت الذكي
    if [ -x "tools/hf_smartfriend_suite_doctor.sh" ]; then
        run_if_exists "7) دكتور SmartFriend Suite (hf_smartfriend_suite_doctor.sh)" "tools/hf_smartfriend_suite_doctor.sh"
    else
        SECTION "7) دكتور SmartFriend Suite"
        log "ℹ️ tools/hf_smartfriend_suite_doctor.sh غير موجود أو غير تنفيذي، تخطي."
    fi

    # 8) فحص الخدمات الكاملة (لو عندك system_services_complete_report)
    if [ -x "collected_scripts/sh_scripts/system_services_complete_report.sh" ]; then
        run_if_exists "8) تقرير كامل لخدمات النظام (system_services_complete_report.sh)" \
            "collected_scripts/sh_scripts/system_services_complete_report.sh"
    else
        SECTION "8) تقرير كامل لخدمات النظام"
        log "ℹ️ collected_scripts/sh_scripts/system_services_complete_report.sh غير موجود أو غير تنفيذي، تخطي."
    fi

    # 9) فحص قواعد البيانات HyperFFactory
    if [ -x "collected_scripts/sh_scripts/hyper_check_all_dbs.sh" ]; then
        run_if_exists "9) فحص قواعد البيانات HyperFFactory (hyper_check_all_dbs.sh)" \
            "collected_scripts/sh_scripts/hyper_check_all_dbs.sh"
    else
        SECTION "9) فحص قواعد البيانات HyperFFactory"
        log "ℹ️ collected_scripts/sh_scripts/hyper_check_all_dbs.sh غير موجود أو غير تنفيذي، تخطي."
    fi

    SECTION "10) ملخص أخير ومسار ملف التقرير"
    log "✅ تم إنشاء تقرير كامل في: $LOG_FILE"
    log "يمكنك مراجعته بـ:"
    log "  less $LOG_FILE"
}

main "$@"
