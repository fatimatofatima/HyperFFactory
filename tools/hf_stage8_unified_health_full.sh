#!/usr/bin/env bash
# HyperFFactory – Stage8 Wrapper:
# 1) تشغيل stage8 الأصلي (Unified Health)
# 2) تشغيل لوحة الجودة / الميتا
# 3) تشغيل محرك الأنماط

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

STAGE_CORE="./tools/hf_stage8_unified_health.sh"
DASHBOARD="./tools/hf_quality_dashboard_cli.sh"
PATTERNS="./tools/hf_patterns_engine_cli.sh"

echo "=================================================="
echo " HyperFFactory – Stage8 Unified Health Full Wrapper"
echo " ROOT : $ROOT"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "=================================================="
echo

if [ ! -x "$STAGE_CORE" ]; then
  echo "❌ ملف stage8 الأساسي غير موجود أو غير قابل للتنفيذ: $STAGE_CORE"
  exit 1
fi

run_step() {
  local label="$1"
  shift
  echo "--------------------------------------------------"
  echo "▶ $label"
  echo "--------------------------------------------------"
  if "$@"; then
    echo "✅ $label – OK"
  else
    local rc=$?
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي الخطوات إن أمكن)"
    return $rc
  fi
  echo
}

# 1) Stage8 الأساسي – صحي حرج
run_step "Stage8 Core: hf_stage8_unified_health.sh" "$STAGE_CORE"

# 2) لوحة الجودة / الميتا
if [ -x "$DASHBOARD" ]; then
  run_step "Quality / Meta Dashboard" "$DASHBOARD" || true
else
  echo "⚠️ لوحة الجودة غير متاحة: $DASHBOARD"
fi

# 3) محرك الأنماط
if [ -x "$PATTERNS" ]; then
  run_step "Patterns Engine (hf_learning → hf_patterns)" "$PATTERNS" || true
else
  echo "⚠️ محرك الأنماط غير متاح: $PATTERNS"
fi

echo "=================================================="
echo " انتهاء Stage8 Unified Health Full Wrapper"
echo "=================================================="
