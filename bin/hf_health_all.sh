#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/HyperFFactory"
REPORT_DIR="$ROOT_DIR/reports"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="$REPORT_DIR/hf_health_report_${TIMESTAMP}.log"

mkdir -p "$REPORT_DIR"

echo "==================================================" | tee "$REPORT_FILE"
echo "🧭 HYPERFFACTORY UNIFIED HEALTH CHECK"              | tee -a "$REPORT_FILE"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"          | tee -a "$REPORT_FILE"
echo "📂 Root : $ROOT_DIR"                             | tee -a "$REPORT_FILE"
echo "==================================================" | tee -a "$REPORT_FILE"
echo | tee -a "$REPORT_FILE"

# فحص أن السكربت يعمل من داخل الهيكل الموحّد
if [[ "$PWD" != "$ROOT_DIR" && "$PWD" != "$ROOT_DIR/"* ]]; then
  echo "❌ هذا السكربت يجب أن يعمل من داخل $ROOT_DIR (الهيكل الموحّد)" | tee -a "$REPORT_FILE"
fi

SMART_SCRIPT="$ROOT_DIR/bin/hf_health_smartfriend.sh"
FF_SCRIPT="$ROOT_DIR/bin/hf_health_ffactory.sh"

if [[ -x "$SMART_SCRIPT" ]]; then
  echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
  echo "🔹 SMARTFRIEND SUITE"                               | tee -a "$REPORT_FILE"
  echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
  "$SMART_SCRIPT" 2>&1 | tee -a "$REPORT_FILE"
else
  echo "❌ سكربت hf_health_smartfriend.sh غير موجود أو غير قابل للتنفيذ: $SMART_SCRIPT" | tee -a "$REPORT_FILE"
fi

echo | tee -a "$REPORT_FILE"

if [[ -x "$FF_SCRIPT" ]]; then
  echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
  echo "🔹 FFACTORY / AI STACK"                            | tee -a "$REPORT_FILE"
  echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
  "$FF_SCRIPT" 2>&1 | tee -a "$REPORT_FILE"
else
  echo "❌ سكربت hf_health_ffactory.sh غير موجود أو غير قابل للتنفيذ: $FF_SCRIPT" | tee -a "$REPORT_FILE"
fi

echo | tee -a "$REPORT_FILE"
echo "==================================================" | tee -a "$REPORT_FILE"
echo "✅ HEALTH CHECK مكتمل – التقرير: $REPORT_FILE"      | tee -a "$REPORT_FILE"
echo "💡 السياسة: التنفيذ من داخل الهيكل الموحّد فقط (/root/HyperFFactory)" | tee -a "$REPORT_FILE"
echo "==================================================" | tee -a "$REPORT_FILE"
