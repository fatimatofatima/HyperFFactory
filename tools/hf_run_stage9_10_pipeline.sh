#!/usr/bin/env bash
# HyperFFactory – Stage9 + Stage10 Pipeline Runner
# Stage9 (Forensics & Gaps) ثم Stage10 (Governance & Dashboards)

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

S9="./tools/hf_stage9_forensics_full.sh"
S10="./tools/hf_stage10_governance_full.sh"

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Stage9 + Stage10 Pipeline"
echo " ROOT : $ROOT"
echo " TIME : $NOW"
echo "=================================================="
echo

run_stage() {
  local label="$1"
  local script="$2"

  echo "▶ تشغيل $label..."
  echo "--------------------------------------------------"

  if [ ! -x "$script" ]; then
    echo "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $script"
    echo
    return
  fi

  set +e
  "$script"
  local rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    echo "✅ $label – OK"
  else
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي الستيجات)"
  fi
  echo
}

run_stage "Stage9 Forensics & Gaps" "$S9"
run_stage "Stage10 Governance & Dashboards" "$S10"

echo "=================================================="
echo " انتهاء Pipeline Stage9 + Stage10"
echo "=================================================="
