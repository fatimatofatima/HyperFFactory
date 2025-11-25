#!/usr/bin/env bash
# HyperFFactory – Stage10 Wrapper:
# Governance / Dashboards / KPIs / Tasks & Schedulers / Patterns

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

DASHBOARD_CLI="./tools/hf_dashboard_cli.sh"
STATUS_SNAPSHOT="./tools/hf_status_snapshot.sh"
KPI_SNAPSHOT="./tools/hf_kpi_snapshot.sh"
TASKS_SCHED="./tools/hf_inspect_tasks_and_schedulers.sh"
QUALITY_DASH="./tools/hf_quality_dashboard_cli.sh"
PATTERNS_CLI="./tools/hf_patterns_engine_cli.sh"
LOG_INCIDENT="./tools/hf_log_incident.sh"

run_step() {
  local label="$1"
  local script="$2"

  echo "--------------------------------------------------"
  echo "▶ $label ($script)"
  echo "--------------------------------------------------"

  if [ ! -x "$script" ]; then
    echo "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $script"
    if [ -x "$LOG_INCIDENT" ]; then
      "$LOG_INCIDENT" "$label" "SCRIPT_NOT_FOUND" "LOW" 127 "$script missing in Stage10"
    fi
    return 127
  fi

  if ! "$script"; then
    local rc=$?
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي المراحل)"
    if [ -x "$LOG_INCIDENT" ]; then
      "$LOG_INCIDENT" "$label" "SCRIPT_FAILURE" "HIGH" "$rc" "$script failed in Stage10"
    fi
    return "$rc"
  fi

  echo "✅ $label – OK"
}

echo "=================================================="
echo " HyperFFactory – Stage10 Governance & Dashboards"
echo " ROOT : $ROOT"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "=================================================="

run_step "Dashboard CLI"                  "$DASHBOARD_CLI"
run_step "Status Snapshot"                "$STATUS_SNAPSHOT"
run_step "KPI Snapshot"                   "$KPI_SNAPSHOT"
run_step "Tasks & Schedulers Inspector"   "$TASKS_SCHED"
run_step "Quality Dashboard CLI"          "$QUALITY_DASH"
run_step "Patterns Engine CLI"            "$PATTERNS_CLI"

echo "=================================================="
echo " ملخص Stage10 – Governance & Dashboards:"
echo "  - تم تشغيل لوحات HyperFFactory الأساسية، snapshots، والمهام والمجدولات."
echo "  - أي فشل يتم تسجيله كـ Incident داخل hf_errors.db (عن طريق hf_log_incident.sh)."
echo "=================================================="
echo "✅ Stage10 Governance & Dashboards – OK"
