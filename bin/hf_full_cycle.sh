#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hf_full_cycle.log"

TS="$(date '+%Y-%m-%d %H:%M:%S')"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

run_step() {
  local label="$1"
  shift
  log "--------------------------------------------------"
  log "[STEP] $label"
  if "$@"; then
    log "[OK]  $label"
  else
    local rc=$?
    log "[ERROR] $label (exit=$rc)"
    exit "$rc"
  fi
}

echo
log "=================================================="
log "🧭 HYPERFFACTORY FULL MANUAL CYCLE"
log "📍 Time : ${TS}"
log "📂 Root : ${ROOT}"
log "=================================================="

# 1) فحص سياسة الشجرة الموحّدة
run_step "hf_assert_unified_tree.sh" bin/hf_assert_unified_tree.sh

# 2) فحص الصحة العام
if [[ -x bin/hf_health_all.sh ]]; then
  run_step "hf_health_all.sh" bin/hf_health_all.sh
else
  log "[WARN] bin/hf_health_all.sh غير موجود – تم تخطي خطوة الصحة."
fi

# 3) دورة العمال (workers)
if [[ -x bin/hf_workers_cycle.sh ]]; then
  run_step "hf_workers_cycle.sh" bin/hf_workers_cycle.sh
else
  log "[WARN] bin/hf_workers_cycle.sh غير موجود – تم تخطي دورة العمال."
fi

# 4) التحقق النهائي من حالة الهيكل/الخطة (اختياري)
if [[ -x bin/hf_verify_unified_status.sh ]]; then
  run_step "hf_verify_unified_status.sh" bin/hf_verify_unified_status.sh
else
  log "[WARN] bin/hf_verify_unified_status.sh غير موجود – تم تخطي خطوة verify."
fi

log "=================================================="
log "✅ FULL CYCLE مكتملة – راجع: ${LOG_FILE}"
log "=================================================="
