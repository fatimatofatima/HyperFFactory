#!/usr/bin/env bash
# HyperFFactory – Unified Management Smart Run
# نقطة دخول واحدة للإدارة:
# - Health + DB checks
# - Plan sync (plan_status + HF_EXEC_PLAN.tsv + hf_ops_meta.db إذا مستخدم)
# - Backups checks
# - Git safe update (اختياري حسب البروفايل)
# - Auto-updater (اختياري حسب البروفايل)
#
# ملاحظات:
# - لا يقوم هذا السكربت بأي git add/commit من نفسه.
# - يعتمد فقط على السكربتات والأدوات الموجودة تحت HyperFFactory.
# - لا يلمس /opt/ffactory أو /opt/smartfriend-suite إلا عبر سكربتات التكامل الموجودة مسبقًا.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

CFG="config/hf_management_profile.yaml"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="reports"
mkdir -p "$LOG_DIR"
LOG="${LOG_DIR}/management_run_${TS}.log"

log() {
  # يكتب على الشاشة + في الملف
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $*" | tee -a "$LOG"
}

get_cfg_raw() {
  local key="$1"
  if [ -f "$CFG" ]; then
    # يأخذ آخر قيمة لو تكرر المفتاح
    grep -E "^${key}:" "$CFG" | tail -n 1 | cut -d':' -f2- | tr -d ' "' || true
  else
    echo ""
  fi
}

get_cfg_flag() {
  local key="$1"
  local def="$2"
  local val
  val="$(get_cfg_raw "$key")"
  if [ -z "$val" ]; then
    echo "$def"
  else
    echo "$val"
  fi
}

is_true() {
  case "$1" in
    true|True|TRUE|1|yes|YES|y|Y|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_cmd() {
  local label="$1"
  shift
  if [ "$#" -eq 0 ]; then
    log "[SKIP] $label – لا يوجد أمر للتنفيذ"
    return 0
  fi
  log "[RUN] $label: $*"
  if "$@" >>"$LOG" 2>&1; then
    log "[OK] $label"
  else
    local rc=$?
    log "[WARN] $label failed (exit=$rc)"
    return "$rc"
  fi
}

FAIL=0

log "====================================================="
log "HyperFFactory – Management Smart Run"
log "ROOT : $ROOT"
log "CFG  : $CFG"
log "TIME : $TS"
log "LOG  : $LOG"
log "====================================================="

if [ ! -f "$CFG" ]; then
  log "[WARN] ملف البروفايل غير موجود: $CFG – استخدام قيم افتراضية (health/plan/backups = ON, git/auto-updater = OFF)"
fi

MODE="$(get_cfg_raw mode || echo "quick")"
HEALTH_ENABLED="$(get_cfg_flag health_enabled true)"
PLAN_SYNC_ENABLED="$(get_cfg_flag plan_sync_enabled true)"
BACKUPS_ENABLED="$(get_cfg_flag backups_enabled true)"
GIT_ENABLED="$(get_cfg_flag git_enabled false)"
AUTO_UPDATER_ENABLED="$(get_cfg_flag auto_updater_enabled false)"

log "[CFG] mode                 = ${MODE}"
log "[CFG] health_enabled       = ${HEALTH_ENABLED}"
log "[CFG] plan_sync_enabled    = ${PLAN_SYNC_ENABLED}"
log "[CFG] backups_enabled      = ${BACKUPS_ENABLED}"
log "[CFG] git_enabled          = ${GIT_ENABLED}"
log "[CFG] auto_updater_enabled = ${AUTO_UPDATER_ENABLED}"

log "-----------------------------------------------------"
log "STEP 1 – Health & DB Checks"
log "-----------------------------------------------------"

if is_true "$HEALTH_ENABLED"; then
  # 1.1 – Unified health (HyperFFactory + SmartFriend + ffactory حسب سكربتاتك)
  if [ -x "bin/hf_health_all.sh" ]; then
    if ! run_cmd "hf_health_all" "bin/hf_health_all.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] bin/hf_health_all.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 1.2 – DB health / inventory
  if [ -x "tools/hyper_check_all_dbs.sh" ]; then
    if ! run_cmd "hyper_check_all_dbs" "tools/hyper_check_all_dbs.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/hyper_check_all_dbs.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 1.3 – Scan health / repo fix reports (SmartFriend + ffactory عبر التقارير)
  if [ -x "tools/hf_scan_health_fix_reports.sh" ]; then
    if ! run_cmd "hf_scan_health_fix_reports" "tools/hf_scan_health_fix_reports.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/hf_scan_health_fix_reports.sh غير موجود أو غير قابل للتنفيذ"
  fi

  if [ -x "tools/hf_scan_repo_health_fix_report.sh" ]; then
    if ! run_cmd "hf_scan_repo_health_fix_report" "tools/hf_scan_repo_health_fix_report.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/hf_scan_repo_health_fix_report.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 1.4 – تشغيل Hyper API (في وضع full فقط)
  if [ "$MODE" = "full" ]; then
    if [ -x "scripts/run_hyper_api.sh" ]; then
      if ! run_cmd "run_hyper_api" "scripts/run_hyper_api.sh"; then
        FAIL=1
      fi
    else
      log "[SKIP] scripts/run_hyper_api.sh غير موجود أو غير قابل للتنفيذ"
    fi
  else
    log "[INFO] mode != full – تخطّي تشغيل run_hyper_api في هذا التشغيل"
  fi
else
  log "[SKIP] Health step معطّل في البروفايل (health_enabled = $HEALTH_ENABLED)"
fi

log "-----------------------------------------------------"
log "STEP 2 – Plan Sync (PLAN_STATUS / HF_EXEC_PLAN / hf_ops_meta)"
log "-----------------------------------------------------"

if is_true "$PLAN_SYNC_ENABLED"; then
  # 2.1 – Sync plan_status + HF_EXEC_PLAN.tsv + hf_ops_meta.db (حسب سكربتك)
  if [ -x "scripts/hf_sync_status_and_plan.sh" ]; then
    if ! run_cmd "hf_sync_status_and_plan" "scripts/hf_sync_status_and_plan.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] scripts/hf_sync_status_and_plan.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 2.2 – عرض الخطة الحالية عبر hf_show_plan.sh
  if [ -x "tools/hf_show_plan.sh" ]; then
    if ! run_cmd "hf_show_plan" "tools/hf_show_plan.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/hf_show_plan.sh غير موجود أو غير قابل للتنفيذ"
  fi
else
  log "[SKIP] Plan Sync step معطّل في البروفايل (plan_sync_enabled = $PLAN_SYNC_ENABLED)"
fi

log "-----------------------------------------------------"
log "STEP 3 – Backups Check"
log "-----------------------------------------------------"

if is_true "$BACKUPS_ENABLED"; then
  # 3.1 – فحص النسخ الاحتياطية
  if [ -x "tools/check_hf_backups.sh" ]; then
    if ! run_cmd "check_hf_backups" "tools/check_hf_backups.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/check_hf_backups.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 3.2 – تقرير سريع للنسخ الاحتياطية
  if [ -x "tools/hf_backups_quick_report.sh" ]; then
    if ! run_cmd "hf_backups_quick_report" "tools/hf_backups_quick_report.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] tools/hf_backups_quick_report.sh غير موجود أو غير قابل للتنفيذ"
  fi
else
  log "[SKIP] Backups step معطّل في البروفايل (backups_enabled = $BACKUPS_ENABLED)"
fi

log "-----------------------------------------------------"
log "STEP 4 – Git Management (Safe) "
log "-----------------------------------------------------"

if is_true "$GIT_ENABLED"; then
  # 4.1 – تحديث الخطة والريبو (status/pull/push حسب ما يفعله السكربت)
  if [ -x "scripts/hf_update_plan_and_repo.sh" ]; then
    if ! run_cmd "hf_update_plan_and_repo" "scripts/hf_update_plan_and_repo.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] scripts/hf_update_plan_and_repo.sh غير موجود أو غير قابل للتنفيذ"
  fi

  # 4.2 – سكربت إدارة Git + Push (حسب تصميمك)
  if [ -x "scripts/hf_build_management_and_push.sh" ]; then
    if ! run_cmd "hf_build_management_and_push" "scripts/hf_build_management_and_push.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] scripts/hf_build_management_and_push.sh غير موجود أو غير قابل للتنفيذ"
  fi
else
  log "[SKIP] Git step معطّل في البروفايل (git_enabled = $GIT_ENABLED)"
fi

log "-----------------------------------------------------"
log "STEP 5 – Auto Updater Setup (اختياري)"
log "-----------------------------------------------------"

if is_true "$AUTO_UPDATER_ENABLED"; then
  if [ -x "scripts/setup_auto_updater.sh" ]; then
    if ! run_cmd "setup_auto_updater" "scripts/setup_auto_updater.sh"; then
      FAIL=1
    fi
  else
    log "[SKIP] scripts/setup_auto_updater.sh غير موجود أو غير قابل للتنفيذ"
  fi
else
  log "[SKIP] Auto-updater step معطّل في البروفايل (auto_updater_enabled = $AUTO_UPDATER_ENABLED)"
fi

log "-----------------------------------------------------"
log "SUMMARY"
log "-----------------------------------------------------"

if [ "$FAIL" -eq 0 ]; then
  log "[SUMMARY] Management run انتهى بدون أخطاء حرجة (FAIL=0)"
else
  log "[SUMMARY] Management run انتهى مع تحذيرات/أخطاء (FAIL=${FAIL}) – راجع اللوج: ${LOG}"
fi

log "====================================================="
log "HyperFFactory – Management Smart Run finished."
log "====================================================="

exit "$FAIL"
