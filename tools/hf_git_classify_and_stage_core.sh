#!/usr/bin/env bash
# HyperFFactory – تصنيف تغييرات Git + إضافة الكود الأساسي فقط
# بدون حذف أي ملف من السيرفر، وبدون رفع الداتا الثقيلة للريبو.

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_git_classify_and_stage_core_${TS}.log"

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

SECTION() {
    echo | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
    echo "== $*" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
}

cd "$ROOT"

SECTION "1) حالة Git الأولية"
log "git status --short:"
git status --short | tee -a "$LOG_FILE" || log "⚠️ git status فشل"

SECTION "2) تصنيف المجلدات (Core Code vs Runtime Data)"

CORE_DIRS=(
  "bin"
  "tools"
  "config"
  "scripts"
  "ops"
  "patterns_system"
  "quality_system"
  "factories"
  "integration_hub"
  "temporal_memory"
  "sql"
  "plans"
)

RUNTIME_DIRS=(
  "data"
  "db"
  "reports"
  "collected_scripts"
  "opt/smartfriend-suite"
)

log "مجلدات الكود الأساسي (مرشحة للإضافة إلى Git):"
for d in "${CORE_DIRS[@]}"; do
    if [ -d "$d" ]; then
        log "  - $d/"
    fi
done

log "مجلدات الداتا التشغيلية/الثقيلة (تبقى محلية فقط):"
for d in "${RUNTIME_DIRS[@]}"; do
    if [ -d "$d" ]; then
        log "  - $d/"
    fi
done

SECTION "3) إضافة الملفات الأساسية المحددة (whitelist)"

# ملفات/سكربتات منفردة مهمّة
CORE_FILES=(
  "bin/hf_assert_unified_tree.sh"
  "bin/hf_guard.sh"
  "bin/hf_management_with_tasks.sh"
  "bin/hf_meta_dump_schemas.sh"
  "plans/HF_EXEC_PLAN.tsv"
  "config/agents.yaml"
  "config/bots_routing.yaml"
  "config/hf_management_profile.yaml"
  "config/modules.json"
  "config/modules_enhanced.json"
  "config/worker_orchestrator.yaml"
  "scripts/spiders/hf_spider_knowledge_poc.sh"
  "ops/run_health.py"
  "tools/hf_repo_status.sh"
)

for f in "${CORE_FILES[@]}"; do
    if [ -e "$f" ]; then
        log "git add $f"
        git add "$f"
    else
        log "تخطّي (غير موجود): $f"
    fi
done

# مجلدات كاملة (كود فقط – لا تشمل data/db/reports/opt...)
CORE_DIRS_TO_ADD=(
  "factories"
  "patterns_system"
  "quality_system"
  "integration_hub"
  "temporal_memory"
  "tools"
  "sql"
)

for d in "${CORE_DIRS_TO_ADD[@]}"; do
    if [ -d "$d" ]; then
        log "git add $d/"
        git add "$d"
    else
        log "تخطّي مجلد غير موجود: $d/"
    fi
done

SECTION "4) مراجعة ما تم عمل stage له"

log "git diff --cached --stat:"
git diff --cached --stat | tee -a "$LOG_FILE" || log "⚠️ git diff --cached فشل"

SECTION "5) إنشاء كوميت تلقائي إذا كان هناك تغييرات"

if git diff --cached --quiet; then
    log "لا توجد ملفات في stage، لن يتم إنشاء كوميت."
else
    COMMIT_MSG="chore: sync HyperFFactory core tools & governance @ ${TS}"
    log "إنشاء كوميت: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" | tee -a "$LOG_FILE" || log "⚠️ git commit فشل"
fi

SECTION "6) حالة Git النهائية"

log "git status:"
git status | tee -a "$LOG_FILE" || log "⚠️ git status فشل"

log "يمكنك الآن (يدوياً) تنفيذ:"
log "  git push origin main"

log "انتهى hf_git_classify_and_stage_core.sh"
