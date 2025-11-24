#!/usr/bin/env bash
# HyperFFactory – Plan & Architecture Gap Audit (Read-Only)
# - لا يعدل ملفات
# - لا يجري git add/commit
# - فقط تقرير عن:
#   * عناصر CORE الموجودة وغير المربوطة بالخطة
#   * عناصر PLANNED المفقودة أو غير المكتملة
#   * فجوات التكامل (ffactory / SmartFriend / Workers / DBs)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="reports"
LOG="$LOG_DIR/hf_plan_arch_audit_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $*" | tee -a "$LOG"
}

check_item() {
  local category="$1"
  local path="$2"

  if [[ -e "$path" ]]; then
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
      log "[$category] ✅ TRACKED   :: $path"
    else
      log "[$category] ⚠️  UNTRACKED :: $path (موجود لكن خارج git – يحتاج قرارك لاحقاً)"
    fi
  else
    log "[$category] ❌ MISSING   :: $path"
  fi
}

log "=================================================="
log "🧩 HyperFFactory – Plan & Architecture Gap Audit"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "=================================================="
log ""

# --------------------------------------------------------------------
# القسم الأول: عناصر CORE الموجودة فعليًا (كانت خارج الخطة / git سابقًا)
# --------------------------------------------------------------------
log "## 1) عناصر CORE الموجودة فعليًا (Management / Brain / SQL / Tools / Workers)"
log "## 1.1) سكربتات إدارة/حوكمة (Management & Plan)"

CORE_MGMT=(
  "scripts/hf_build_management_and_push.sh"
  "scripts/hf_management_smart_run.sh"
  "scripts/hf_setup_management_and_push.sh"
  "scripts/hf_sync_status_and_plan.sh"
  "scripts/hf_update_plan_and_repo.sh"
  "scripts/run_hyper_api.sh"
  "scripts/setup_auto_updater.sh"
)

for p in "${CORE_MGMT[@]}"; do
  check_item "CORE-MGMT" "$p"
done

log ""
log "## 1.2) مكوّنات Brain / AI بسيطة"

CORE_BRAIN=(
  "self_learning_brain.py"
  "simple_brain.py"
)

for p in "${CORE_BRAIN[@]}"; do
  check_item "CORE-BRAIN" "$p"
done

log ""
log "## 1.3) طبقة SQL / نماذج البيانات"

CORE_SQL=(
  "sql"
  "sql/unified_data_model_schema.sql"
)

for p in "${CORE_SQL[@]}"; do
  check_item "CORE-SQL" "$p"
done

log ""
log "## 1.4) سكربتات أدوات HyperFFactory (tools/*) المذكورة في القائمة"

CORE_TOOLS=(
  "tools/check_hf_backups.sh"
  "tools/execute_safe_cleanup.sh"
  "tools/final_verification.sh"
  "tools/hf_backups_quick_report.sh"
  "tools/hf_cleanup_unpacked.sh"
  "tools/hf_enforce_unified_root.sh"
  "tools/hf_find_smartfriend_unified_db.sh"
  "tools/hf_flatten_src_to_root.sh"
  "tools/hf_hide_default_motd.sh"
  "tools/hf_index_scripts.sh"
  "tools/hf_inspect_and_fix_src.sh"
  "tools/hf_quarantine_archives.sh"
  "tools/hf_root_cleanup.sh"
  "tools/hf_scan_brain_memory_quality.sh"
  "tools/hf_scan_health_fix_reports.sh"
  "tools/hf_scan_repo_health_fix_report.sh"
  "tools/hf_set_login_banner.sh"
  "tools/hf_show_plan.sh"
  "tools/hf_update_readme_real.sh"
  "tools/hyper_check_all_dbs.sh"
  "tools/hyper_list_db_users.sh"
)

for p in "${CORE_TOOLS[@]}"; do
  check_item "CORE-TOOLS" "$p"
done

log ""
log "## 1.5) طبقة العمال (Workers Layer)"

check_item "CORE-WORKERS" "workers"
check_item "CORE-WORKERS" "workers/ingestor_basic.sh"
check_item "CORE-WORKERS" "workers/processor_basic.sh"
check_item "CORE-WORKERS" "workers/analyzer_basic.sh"
check_item "CORE-WORKERS" "workers/reporter_basic.sh"

log ""
log "## 1.6) ملفات/مجلدات بأسماء عربية – Manual Review فقط (لا لمس للملفات)"
log "   هذه العناصر تم تركها للمراجعة اليدوية، السكربت لا يلمسها:"
log "   - \"\\\\330\\\\243\\\\331\\\\212\""
log "   - \"\\\\330\\\\247\\\\331\\\\204\\\\330\\\\252\\\\331\\\\206\\\\331\\\\201\\\\331\\\\212\\\\330\\\\260\""
log "   - \"\\\\330\\\\254\\\\331\\\\205\\\\331\\\\212\\\\330\\\\271\""
log "   - \"\\\\331\\\\205\\\\331\\\\207\\\\331\\\\205:\""
log ""

# --------------------------------------------------------------------
# القسم الثاني: عناصر PLANNED مذكورة في التقارير لكن ناقصة/غير مكتملة
# --------------------------------------------------------------------
log "## 2) عناصر PLANNED مذكورة في المستندات/التقارير (Governance / Agents / Quality / Learning / Errors)"

log ""
log "### 2.1) Agents / Orchestrator Config (من تقارير hf_check_advanced_arch)"

PLANNED_CONFIGS=(
  "config/agents.yaml"
  "config/worker_orchestrator.yaml"
  "config/modules.json"
  "config/modules_enhanced.json"
)

for p in "${PLANNED_CONFIGS[@]}"; do
  check_item "PLANNED-CONFIG" "$p"
done

log ""
log "🔎 ملاحظة: هناك ملف موجود بالفعل قد يكون بديلًا جزئيًا:"
check_item "ALT-CONFIG" "config/integration_smartfriend.yaml"
check_item "ALT-CONFIG" "config/lakehouse_manifest.yaml"
check_item "ALT-CONFIG" "config/unified_data_model.yaml"

log ""
log "### 2.2) أنظمة الجودة / التعلّم (hf_quality.db / hf_learning.db)"

QUALITY_DB="db/meta/hf_quality.db"
LEARNING_DB="db/meta/hf_learning.db"

check_item "PLANNED-DB" "$QUALITY_DB"
check_item "PLANNED-DB" "$LEARNING_DB"

if command -v sqlite3 >/dev/null 2>&1; then
  if [[ -f "$QUALITY_DB" ]]; then
    log "[DB-CHECK] فحص جدول quality_events داخل $QUALITY_DB"
    sqlite3 "$QUALITY_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='quality_events';" \
      2>>"$LOG" | sed 's/^/[DB-CHECK]   TABLE: /' | tee -a "$LOG" || true
  fi
  if [[ -f "$LEARNING_DB" ]]; then
    log "[DB-CHECK] فحص جدول learning_skill_states داخل $LEARNING_DB"
    sqlite3 "$LEARNING_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='learning_skill_states';" \
      2>>"$LOG" | sed 's/^/[DB-CHECK]   TABLE: /' | tee -a "$LOG" || true
  fi
else
  log "[DB-CHECK] ⚠️ sqlite3 غير متوفر – تخطّي فحص الجداول (structure فقط)."
fi

log ""
log "### 2.3) نظام Incidents / Errors المتكامل"

ERRORS_DB="db/meta/hf_errors.db"
OPS_META_DB="db/meta/hf_ops_meta.db"

check_item "PLANNED-DB" "$ERRORS_DB"
check_item "PLANNED-DB" "$OPS_META_DB"

if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$ERRORS_DB" ]]; then
  log "[DB-CHECK] فحص جداول الحوادث الأساسية داخل $ERRORS_DB"
  sqlite3 "$ERRORS_DB" "SELECT name FROM sqlite_master WHERE type='table';" \
    2>>"$LOG" | sed 's/^/[DB-TABLE] /' | tee -a "$LOG" || true
fi

log ""
log "### 2.4) ربط الخطة مع hf_ops_meta.tasks (Plan ↔ Tasks)"

PLAN_FILES=(
  "PLAN_STATUS.md"
  "plan_status.md"
  "plans/HF_EXEC_PLAN.tsv"
  "tools/hf_show_plan.sh"
)

for p in "${PLAN_FILES[@]}"; do
  check_item "PLAN-FILES" "$p"
done

log "[INFO] الربط المنطقي بين HF_EXEC_PLAN.tsv و hf_ops_meta.tasks مازال PLANNED – هذا السكربت فقط يفحص وجود الملفات/الـ DB."

# --------------------------------------------------------------------
# القسم الثالث: فجوات التكامل (ffactory / SmartFriend / Workers / Git Management)
# --------------------------------------------------------------------
log ""
log "## 3) فجوات التكامل المذكورة في التقارير"

log ""
log "### 3.1) ffactory Bridge الرسمي (سكربتات التكامل مع /opt/ffactory)"

FF_BRIDGE=(
  "scripts/integration/integrate_ffactory2.sh"
)

for p in "${FF_BRIDGE[@]}"; do
  check_item "FFACTORY-BRIDGE" "$p"
done

# أي سكربتات core لها prefix ffactory_ تحت scripts/core (لو المجلد موجود)
if [[ -d "scripts/core" ]]; then
  log "[SCAN] قائمة سكربتات scripts/core/ffactory_* (إن وجدت):"
  find scripts/core -maxdepth 1 -type f -name "ffactory_*" -printf "[FF-CORE] %P\n" 2>/dev/null | tee -a "$LOG" || true
else
  log "[FF-CORE] scripts/core غير موجود حالياً."
fi

log ""
log "### 3.2) SmartFriend Suite Integration – على مستوى HyperFFactory"

check_item "SMARTFRIEND-INTEGRATION" "config/integration_smartfriend.yaml"
check_item "SMARTFRIEND-INTEGRATION" "bin/hyper_bootstrap_smartfriend_suite.sh"
check_item "SMARTFRIEND-INTEGRATION" "bin/hyper_recover_smartfriend_unified.sh"
check_item "SMARTFRIEND-INTEGRATION" "tools/hf_scan_health_fix_reports.sh"
check_item "SMARTFRIEND-INTEGRATION" "tools/hf_scan_repo_health_fix_report.sh"

log "[INFO] لا يوجد حتى الآن ملف config رسمي باسم smartfriend_integration.yaml – ما زال جزء من P2 كما في المستندات."

log ""
log "### 3.3) سكربتات إدارة Git / Push / Auto-update"

GIT_MGMT=(
  "scripts/hf_build_management_and_push.sh"
  "scripts/hf_setup_management_and_push.sh"
  "scripts/hf_update_plan_and_repo.sh"
  "scripts/hf_sync_status_and_plan.sh"
  "scripts/setup_auto_updater.sh"
)

for p in "${GIT_MGMT[@]}"; do
  check_item "GIT-MGMT" "$p"
done

log "[INFO] هذه السكربتات الآن موجودة ومتتبعة في git، لكن سياسة استخدامها ضمن Governance مازالت PLANNED على مستوى الخطة."

log ""
log "### 3.4) طبقة Workers – ربط العمال مع الخطة والـ DBs"

check_item "WORKERS" "workers/ingestor_basic.sh"
check_item "WORKERS" "workers/processor_basic.sh"
check_item "WORKERS" "workers/analyzer_basic.sh"
check_item "WORKERS" "workers/reporter_basic.sh"

log "[INFO] حالياً يوجد وصف أساسي للـ pipeline (ingestor → processor → analyzer → reporter) لكن لا يوجد mapping كامل لكل عامل إلى:"
log "       - جداول محددة في db/meta/*"
log "       - بنود محددة في HF_EXEC_PLAN.tsv"
log "       هذا السكربت يسجّل الفجوة فقط بدون أي تعديل."

log ""
log "=================================================="
log "🔚 انتهى فحص Plan & Architecture (قراءة فقط)."
log "   راجع: $LOG"
log "=================================================="

