#!/usr/bin/env bash
# HyperFFactory – One Control Cycle
# يربط Quality/Errors → Tasks → Experience → Snapshot/Dashboard
# READ/WRITE فقط عبر السكربتات القائمة (لا يلمس قواعد البيانات مباشرة).

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

ts() { date +"%Y-%m-%d %H:%M:%S %z"; }

log() {
  local level="$1"; shift
  echo "$(ts) [CONTROL] [$level] $*"
}

echo "====================================================="
echo " HyperFFactory – Control Cycle"
echo " ROOT : $ROOT"
echo " TIME : $(ts)"
echo "====================================================="

# 1) Feedback من Quality/Errors إلى Tasks (إن وجد)
if [[ -x tools/hf_tasks_feedback_from_quality_and_errors.sh ]]; then
  log INFO "Running hf_tasks_feedback_from_quality_and_errors.sh (Quality/Errors → Tasks)..."
  if ! bash tools/hf_tasks_feedback_from_quality_and_errors.sh; then
    log WARN "hf_tasks_feedback_from_quality_and_errors.sh انتهى بخطأ، استمر في الدورة."
  fi
else
  log WARN "tools/hf_tasks_feedback_from_quality_and_errors.sh غير موجود أو غير قابل للتنفيذ."
fi

# 2) تحديث نظام الخبرة
if [[ -x tools/hf_experience_init.sh ]]; then
  log INFO "Running hf_experience_init.sh (update hf_actor_stats)..."
  bash tools/hf_experience_init.sh
else
  log WARN "tools/hf_experience_init.sh غير موجود أو غير قابل للتنفيذ."
fi

if [[ -x tools/hf_experience_report.sh ]]; then
  log INFO "Running hf_experience_report.sh (print experience summary)..."
  bash tools/hf_experience_report.sh || log WARN "hf_experience_report.sh انتهى بخطأ."
else
  log WARN "tools/hf_experience_report.sh غير موجود أو غير قابل للتنفيذ."
fi

# 3) Snapshot + Dashboard
if [[ -x tools/hf_status_snapshot.sh ]]; then
  log INFO "Running hf_status_snapshot.sh..."
  bash tools/hf_status_snapshot.sh || log WARN "hf_status_snapshot.sh انتهى بخطأ."
else
  log WARN "tools/hf_status_snapshot.sh غير موجود أو غير قابل للتنفيذ."
fi

if [[ -x tools/hf_dashboard_cli.sh ]]; then
  log INFO "Running hf_dashboard_cli.sh (أول صفحة فقط)..."
  bash tools/hf_dashboard_cli.sh | head -80 || log WARN "hf_dashboard_cli.sh انتهى بخطأ."
else
  log WARN "tools/hf_dashboard_cli.sh غير موجود أو غير قابل للتنفيذ."
fi

log INFO "Control Cycle انتهت."
