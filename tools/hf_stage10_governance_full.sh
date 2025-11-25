#!/usr/bin/env bash
# HyperFFactory – Stage10 Wrapper:
# Governance / Dashboards / KPIs / Tasks & Schedulers

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

DASHBOARD_CLI="./tools/hf_dashboard_cli.sh"
STATUS_SNAPSHOT="./tools/hf_status_snapshot.sh"
KPI_SNAPSHOT="./tools/hf_kpi_snapshot.sh"
TASKS_SCHED="./tools/hf_inspect_tasks_and_schedulers.sh"
QUALITY_DASH="./tools/hf_quality_dashboard_cli.sh"
PATTERNS_CLI="./tools/hf_patterns_engine_cli.sh"

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Stage10 Governance & Dashboard Wrapper"
echo " ROOT : $ROOT"
echo " TIME : $NOW"
echo "=================================================="
echo

log_incident() {
  local actor="$1"
  local error_type="$2"
  local severity="$3"
  local message="$4"
  local context="$5"
  local exit_code="${6:-1}"
  local report_path="${7:-}"

  if [ -x "./tools/hf_log_incident.sh" ]; then
    HF_ROOT="$ROOT" HF_SOURCE_SCRIPT="hf_stage10_governance_full.sh" \
      ./tools/hf_log_incident.sh "$actor" "$error_type" "$severity" "$message" "$context" "$exit_code" "$report_path" || true
  fi
}

run_step() {
  local label="$1"
  local script="$2"
  local severity="${3:-MEDIUM}"

  echo "--------------------------------------------------"
  echo "▶ $label"
  echo "--------------------------------------------------"

  if [ ! -x "$script" ]; then
    echo "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $script"
    log_incident "$label" "SCRIPT_NOT_FOUND" "$severity" "Script not found or not executable: $script" "ROOT=$ROOT;TIME=$NOW" 127 "$script"
    echo
    return
  fi

  set +e
  HF_ROOT="$ROOT" HF_SOURCE_SCRIPT="$script" "$script" | sed 's/^/  /'
  local rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    echo "✅ $label – OK"
  else
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي المراحل)"
    log_incident "$label" "SCRIPT_FAILURE" "$severity" "Script $script failed with exit code $rc" "ROOT=$ROOT;TIME=$NOW" "$rc"
  fi
  echo
}

# 1) لوحة HyperFFactory العامة
run_step "Main HyperFFactory Dashboard (hf_dashboard_cli.sh)" "$DASHBOARD_CLI" "MEDIUM"

# 2) Snapshots للحالة العامة و KPIs
run_step "Status Snapshot (hf_status_snapshot.sh)" "$STATUS_SNAPSHOT" "LOW"
run_step "KPI Snapshot (hf_kpi_snapshot.sh)" "$KPI_SNAPSHOT" "LOW"

# 3) تحليل المهام والمجدولات
run_step "Tasks & Schedulers Inspection (hf_inspect_tasks_and_schedulers.sh)" "$TASKS_SCHED" "MEDIUM"

# 4) لوحة الجودة / الميتا + محرك الأنماط
run_step "Quality / Meta Dashboard (hf_quality_dashboard_cli.sh)" "$QUALITY_DASH" "LOW"
run_step "Patterns Engine (hf_patterns_engine_cli.sh)" "$PATTERNS_CLI" "LOW"

echo "=================================================="
echo " ملخص Stage10 – Governance & Dashboards:"
echo "  - تم تشغيل لوحات HyperFFactory الأساسية، snapshots، والمهام والمجدولات."
echo "  - أي فشل تم تسجيله كنظام Incidents في hf_errors.db."
echo "=================================================="
