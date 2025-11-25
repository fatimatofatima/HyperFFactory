#!/usr/bin/env bash
# HyperFFactory – Integration Phase Runner (mode=light)
# - يعمل داخل /root/HyperFFactory فقط
# - Steps:
#   0) فحص ROOT والأدوات الأساسية (تحذيري – لا يوقف الباقي في mode=light)
#   2) Meta systems (hf_run_meta_systems.sh)
#   3) Unified integration (hf_run_unified_integration.sh)

set -u -o pipefail

#--------------------------------------
# 1) ضبط ROOT و LOG
#--------------------------------------
ROOT="${1:-${ROOT:-/root/HyperFFactory}}"

if [[ -z "${ROOT}" ]]; then
  ROOT="/root/HyperFFactory"
fi

ts() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

log() {
  printf '%s %s\n' "$(ts)" "$*" 
}

LOG_DIR="${ROOT}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/hf_integration_phase_runner_$(date '+%Y%m%d_%H%M%S').log"

log "============================================================"
log "== HF Integration Phase Runner (mode=light)"
log "============================================================"
log "ROOT : ${ROOT}"
log "LOG  : ${LOG_FILE}"
log "============================================================"

# توجيه stdout/stderr أيضاً إلى ملف اللوج (بدون تعطيل الإخراج على الشاشة)
exec > >(tee -a "${LOG_FILE}") 2>&1

#--------------------------------------
# 2) STEP 0 – فحص ROOT والأدوات
#--------------------------------------
log "---- START STEP: 0) فحص أساسي للمسار والأدوات ----"

rc0=0

# ضمان أن ROOT ليس فارغاً، وإن كان فارغاً نستخدم القيمة الافتراضية
if [[ -z "${ROOT}" ]]; then
  log "WARN ROOT فارغ – تعيينه افتراضياً إلى /root/HyperFFactory"
  ROOT="/root/HyperFFactory"
fi

# فحص وجود المجلد
if [[ ! -d "${ROOT}" ]]; then
  log "ERROR ROOT غير موجود على القرص: ${ROOT}"
  rc0=1
else
  log "ROOT OK: ${ROOT}"
fi

# فحص بعض الأدوات الأساسية (تحذيري فقط في mode=light)
for cmd in sqlite3 docker curl systemctl; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    log "CHECK TOOL: ${cmd} → موجود"
  else
    log "WARN TOOL: ${cmd} غير موجود في PATH (لن يوقف التنفيذ في mode=light)"
  fi
done

if (( rc0 != 0 )); then
  log "WARN FAILED STEP: 0) فحص أساسي للمسار والأدوات (rc=${rc0} – سيتم الاستمرار)"
else
  log "DONE STEP: 0) فحص أساسي للمسار والأدوات"
fi

log "-----------------------------"

#--------------------------------------
# Helper لتشغيل step مع كود خروج غير قاتل
#--------------------------------------
run_step() {
  local step_id="$1"
  local description="$2"
  shift 2
  local cmd=( "$@" )

  log "---- START STEP: ${step_id}) ${description} ----"
  if [[ ${#cmd[@]} -eq 0 ]]; then
    log "WARN STEP ${step_id}: لا يوجد أمر للتنفيذ (skip)."
    return 0
  fi

  # تشغيل السكربت الفرعي
  "${cmd[@]}"
  local rc=$?

  if (( rc != 0 )); then
    log "WARN FAILED STEP: ${step_id}) ${description} (rc=${rc} – سيتم الاستمرار)"
  else
    log "DONE STEP: ${step_id}) ${description}"
  fi

  log "-----------------------------"
  return 0
}

#--------------------------------------
# 3) STEP 2 – Meta systems (hf_run_meta_systems.sh)
#--------------------------------------
META_RUNNER="${ROOT}/tools/hf_run_meta_systems.sh"
if [[ -x "${META_RUNNER}" ]]; then
  run_step "2" "Meta systems (hf_run_meta_systems.sh)" "${META_RUNNER}"
else
  log "WARN STEP 2: لم يتم العثور على ${META_RUNNER} أو غير قابل للتنفيذ – تخطي."
fi

#--------------------------------------
# 4) STEP 3 – Unified integration (hf_run_unified_integration.sh)
#--------------------------------------
UNI_RUNNER="${ROOT}/tools/hf_run_unified_integration.sh"
if [[ -x "${UNI_RUNNER}" ]]; then
  run_step "3" "Unified integration (hf_run_unified_integration.sh)" "${UNI_RUNNER}"
else
  log "WARN STEP 3: لم يتم العثور على ${UNI_RUNNER} أو غير قابل للتنفيذ – تخطي."
fi

#--------------------------------------
# 5) SUMMARY
#--------------------------------------
log "============================================================"
log "انتهت دورة HF Integration Phase Runner (mode=light)."
log "راجع اللوج عند الحاجة:"
log "  ${LOG_FILE}"
log "============================================================"
