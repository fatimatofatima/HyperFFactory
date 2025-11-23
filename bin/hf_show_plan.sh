#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/HyperFFactory"
PLAN_FILE="$ROOT_DIR/PLAN_STATUS.md"
README_FILE="$ROOT_DIR/README.md"

echo "=================================================="
echo "📋 HYPERFFACTORY – خطة العمل والحالة الحالية"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : $ROOT_DIR"
echo "=================================================="
echo

# التحقق من العمل من داخل الهيكل الموحّد
if [[ "$PWD" != "$ROOT_DIR" && "$PWD" != "$ROOT_DIR/"* ]]; then
  echo "❌ تشغيل من خارج الهيكل الموحّد غير مسموح."
  echo "🔒 يجب العمل من داخل: $ROOT_DIR"
  echo "⚠️ هذا يعتبر مخالفة لسياسة التشغيل ويجب إصلاح مسارات الأوامر."
  exit 1
fi

if [[ -f "$README_FILE" ]]; then
  echo "---------------- README (الخلفية والهوية) ----------------"
  cat "$README_FILE"
  echo
else
  echo "⚠️ README.md غير موجود في $README_FILE"
  echo
fi

if [[ -f "$PLAN_FILE" ]]; then
  echo "---------------- PLAN_STATUS (ما تم / المتبقي) -----------"
  cat "$PLAN_FILE"
  echo
else
  echo "⚠️ PLAN_STATUS.md غير موجود في $PLAN_FILE"
  echo
fi

echo "=================================================="
echo "✅ نهاية عرض الخطة. السياسة: التنفيذ داخل الهيكل الموحّد فقط."
echo "=================================================="
