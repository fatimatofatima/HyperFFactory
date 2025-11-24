#!/usr/bin/env bash
# HyperFFactory – Run All Core Checks (Plan + Health + Backup + HeavyData)
# الهدف:
# - تشغيل كل سكربتات الفحص الأساسية الموجودة (بدون تعديل ملفات الكود).
# - تجميع Log واحد شامل لمسار الفحوصات.
#
# ملاحظات:
# - بعض السكربتات قد تكتب في قواعد db/meta/* (مثل hf_sync_plan_to_tasks.sh) حسب تصميمها.
# - هذا السكربت نفسه لا يعدّل git ولا يحذف أي بيانات.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPORT_DIR}/hf_run_all_core_checks_${TS}.log"

log() {
  echo "[$(date +'%Y-%m-%d_%H:%M:%S')] $*" | tee -a "$LOG"
}

run_step() {
  local label="$1"
  local cmd="$2"

  log "-----------------------------------------------------"
  log "[STEP] $label"
  log "CMD  : $cmd"

  # نفكّر في وجود السكربت قبل التشغيل لو كان ملف
  local first_word
  first_word="$(echo "$cmd" | awk '{print $1}')"

  if [[ "$first_word" == tools/* || "$first_word" == bin/* ]]; then
    if [[ ! -x "$first_word" ]]; then
      log "[SKIP] $first_word غير موجود أو غير قابل للتنفيذ – تخطّي."
      return 0
    fi
  fi

  if bash -c "$cmd"; then
    log "[OK] STEP '$label' انتهى بنجاح."
  else
    log "[WARN] STEP '$label' انتهى بخطأ (exit != 0) – راجع المخرجات أعلاه."
  fi
}

{
  echo "====================================================="
  echo "[RUN-ALL] HyperFFactory – Run All Core Checks"
  echo "ROOT : ${ROOT}"
  echo "TIME : ${TS}"
  echo "LOG  : ${LOG}"
  echo "====================================================="
} | tee "$LOG"

# 1) فحص سكربتات الصحة/الإصلاح/التقارير في الريبو
run_step "Scan Repo Health/Fix/Report Scripts Index" \
  "tools/hf_scan_repo_health_fix_report.sh"

# 2) فهرسة كل سكربتات health/fix/report في الشجرة
run_step "Scan Health/Fix/Report Scripts Tree" \
  "tools/hf_scan_health_fix_reports.sh"

# 3) Snapshot لفجوات الخطة والمعمارية (Remaining Gaps)
run_step "Remaining Gaps Summary (Plan + Arch)" \
  "tools/hf_check_remaining_gaps.sh"

# 4) تقرير فجوات ملفات الـ Config (agents / orchestrator / modules)
run_step "Config Gaps Report" \
  "tools/hf_config_gaps_report.sh"

# 5) Snapshot سياسة الـ Backup (P2-4)
run_step "Backup Policy Snapshot" \
  "tools/hf_backup_policy_snapshot.sh"

# 6) Manifest للداتا الثقيلة / snapshots / imported (P2-6)
run_step "Heavy Data Manifest" \
  "tools/hf_heavy_data_manifest.sh"

# 7) فحص قواعد بيانات HyperFFactory (عامة)
run_step "Hyper – Check All DBs" \
  "tools/hyper_check_all_dbs.sh"

run_step "Hyper – List DB Users" \
  "tools/hyper_list_db_users.sh"

# 8) Dump سكيما قواعد meta (hf_meta_* ) – لو السكربت موجود
run_step "Meta Schemas Dump (hf_meta_dump_schemas)" \
  "bin/hf_meta_dump_schemas.sh"

# 9) مزامنة الخطة مع جدول hf_ops_meta.tasks – لو السكربت موجود
run_step "Sync Plan → hf_ops_meta.tasks" \
  "tools/hf_sync_plan_to_tasks.sh"

log "====================================================="
log "[RUN-ALL] انتهى تشغيل كل الفحوصات الأساسية (مع التجاوز الآمن لما هو غير موجود)."
log "         راجع هذا الملف كمحور رئيسي:"
log "         $LOG"
log "====================================================="

echo
echo "[RUN-ALL] All core checks pipeline finished."
echo "[RUN-ALL] Main log: $LOG"
