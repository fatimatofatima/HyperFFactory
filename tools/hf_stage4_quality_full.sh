#!/usr/bin/env bash
# HyperFFactory – Stage4 Wrapper:
# 1) تشغيل stage4 الأصلي للجودة/الأخطاء/التعلم
# 2) تشغيل لوحة الجودة / الميتا
# 3) تشغيل محرك الأنماط (patterns) اعتمادًا على hf_learning.db

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

STAGE_CORE="./tools/hf_stage4_quality_errors_learning.sh"
DASHBOARD="./tools/hf_quality_dashboard_cli.sh"
PATTERNS="./tools/hf_patterns_engine_cli.sh"

echo "=================================================="
echo " HyperFFactory – Stage4 Quality Full Wrapper"
echo " ROOT : $ROOT"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "=================================================="
echo

if [ ! -x "$STAGE_CORE" ]; then
  echo "❌ ملف stage4 الأساسي غير موجود أو غير قابل للتنفيذ: $STAGE_CORE"
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

# 1) Stage4 الأساسي – هذا هو الخط الحرج
run_step "Stage4 Core: hf_stage4_quality_errors_learning.sh" "$STAGE_CORE"

# 2) لوحة الجودة / الميتا – لو فشلت نعرض تحذير فقط
if [ -x "$DASHBOARD" ]; then
  run_step "Quality / Meta Dashboard" "$DASHBOARD" || true
else
  echo "⚠️ لوحة الجودة غير متاحة: $DASHBOARD"
fi

# 3) محرك الأنماط – قراءة من hf_learning وكتابة إلى hf_patterns
if [ -x "$PATTERNS" ]; then
  run_step "Patterns Engine (hf_learning → hf_patterns)" "$PATTERNS" || true
else
  echo "⚠️ محرك الأنماط غير متاح: $PATTERNS"
fi

echo "=================================================="
echo " انتهاء Stage4 Quality Full Wrapper"
echo "=================================================="
