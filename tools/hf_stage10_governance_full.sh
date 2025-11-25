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

run_step() {
  local label="$1"
  local script="$2"

  echo "--------------------------------------------------"
  echo "▶ $label"
  echo "--------------------------------------------------"

  if [ ! -x "$script" ]; then
    echo "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $script"
    echo
    return
  fi

  set +e
  "$script" | sed 's/^/  /'
  local rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    echo "✅ $label – OK"
  else
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي المراحل)"
  fi
  echo
}

# 1) لوحة HyperFFactory العامة (dashboard CLI)
run_step "Main HyperFFactory Dashboard (hf_dashboard_cli.sh)" "$DASHBOARD_CLI"

# 2) Snapshots للحالة العامة و KPIs
run_step "Status Snapshot (hf_status_snapshot.sh)" "$STATUS_SNAPSHOT"
run_step "KPI Snapshot (hf_kpi_snapshot.sh)" "$KPI_SNAPSHOT"

# 3) تحليل المهام والمجدولات من المصدر الرسمي hf_ops_meta
run_step "Tasks & Schedulers Inspection (hf_inspect_tasks_and_schedulers.sh)" "$TASKS_SCHED"

# 4) لوحة الجودة / الميتا + محرك الأنماط (للمراجعة Governance)
run_step "Quality / Meta Dashboard (hf_quality_dashboard_cli.sh)" "$QUALITY_DASH"
run_step "Patterns Engine (hf_patterns_engine_cli.sh)" "$PATTERNS_CLI"

echo "=================================================="
echo " ملخص Stage10 – Governance & Dashboards:"
echo "  - تم تشغيل لوحات HyperFFactory الأساسية، snapshots، وقراءة المهام والمجدولات."
echo "  - تم تضمين جودة/أنماط كجزء من حوكمة المصنع."
echo "=================================================="
