#!/usr/bin/env bash
# HyperFFactory - Daily Health Pipeline
# 1) تشغيل hf_health_all.sh
# 2) استيراد التقرير إلى الجودة/الأخطاء/التعلّم (hf_quality_from_health.sh)
# 3) تسجيل التقدّم وربطها بنظام المهام (إن وجد)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
REPORTS_DIR="$ROOT_DIR/reports"

HEALTH_ALL="$ROOT_DIR/bin/hf_health_all.sh"
IMPORT_HEALTH="$ROOT_DIR/bin/hf_quality_from_health.sh"
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
TASKS_ADD="$ROOT_DIR/bin/hf_tasks_add.sh"

ts="$(date '+%Y-%m-%d %H:%M:%S')"
task_id=""

echo "=================================================="
echo "🩺 HyperFFactory – Daily Health Pipeline"
echo "📍 Root : $ROOT_DIR"
echo "🕒 Time : $ts"
echo "=================================================="

# 0) تسجيل مهمة (اختياري)
if [[ -x "$TASKS_ADD" ]]; then
  # Usage: hf_tasks_add.sh <actor> <scope> <status> <priority> <title...>
  # نضيف مهمة بحالة PLANNED أولًا
  out="$("$TASKS_ADD" "hyper_brain_controller" "health" "PLANNED" 1 "Daily unified health check")" || true
  # نحاول استخراج id لو طُبع في الإخراج
  task_id="$(printf '%s\n' "$out" | awk -F':' '/id/{gsub(/ /,"",$2);print $2}' | head -n1 || true)"
  if [[ -n "$task_id" ]]; then
    echo "📝 Task registered: id=$task_id"
  fi
fi

# 1) حفظ آخر تقرير قبل التشغيل
last_before="$(ls -t "$REPORTS_DIR"/hf_health_report_*.log 2>/dev/null | head -n1 || true)"

# 2) تشغيل health_all
if [[ ! -x "$HEALTH_ALL" ]]; then
  echo "❌ $HEALTH_ALL غير موجود أو غير قابل للتنفيذ." >&2
  exit 1
fi

echo "▶ تشغيل hf_health_all.sh ..."
if ! "$HEALTH_ALL"; then
  health_status="FAILED"
else
  health_status="DONE"
fi

# 3) تحديد التقرير الأحدث
last_after="$(ls -t "$REPORTS_DIR"/hf_health_report_*.log 2>/dev/null | head -n1 || true)"

if [[ -z "$last_after" ]]; then
  echo "⚠️ لم يتم العثور على أي تقرير hf_health_report_*.log بعد التشغيل." >&2
else
  if [[ "$last_after" != "$last_before" && -n "$last_after" ]]; then
    echo "📄 تم إنشاء تقرير جديد: $(basename "$last_after")"
  else
    echo "ℹ️ لم يتغير اسم التقرير الأحدث، سيتم استخدام: $(basename "$last_after")"
  fi

  if [[ -x "$IMPORT_HEALTH" ]]; then
    echo "▶ استيراد التقرير إلى الجودة/الأخطاء/التعلّم ..."
    "$IMPORT_HEALTH" "$last_after"
  else
    echo "⚠️ $IMPORT_HEALTH غير موجود أو غير قابل للتنفيذ – لن يتم الاستيراد." >&2
  fi
fi

# 4) تسجيل التقدّم
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_daily_health_pipeline" "$health_status" "report=$(basename "${last_after:-none}") task_id=${task_id:-none}"
fi

echo "=================================================="
echo "✅ Daily Health Pipeline انتهى (status=$health_status)"
echo "=================================================="
