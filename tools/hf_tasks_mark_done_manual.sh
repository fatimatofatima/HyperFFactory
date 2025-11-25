#!/usr/bin/env bash
# HF Challenge – Manual task closer (PLANNED → DONE) مع تأكيد يدوي.
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
TASKS_DB="$HYPER_ROOT/db/meta/hf_tasks.db"

cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

if [[ ! -f "$TASKS_DB" ]]; then
  echo "❌ قاعدة المهام غير موجودة: $TASKS_DB"
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <TASK_ID>"
  echo
  echo "مثال:"
  echo "  $0 4   # لتقفيل المهمة رقم 4 (backup_policy مثلاً)"
  exit 1
fi

TASK_ID="$1"

echo "====================================================="
echo "HF Challenge – Manual Task Close"
echo "====================================================="
echo "DB      : $TASKS_DB"
echo "TASK_ID : $TASK_ID"
echo

# 1) جلب تفاصيل المهمة
echo "[i] جلب بيانات المهمة من hf_tasks.db..."
TASK_ROW="$(sqlite3 -line "$TASKS_DB" "SELECT id, actor, scope, status, priority, title, created_at, updated_at FROM tasks WHERE id = $TASK_ID;")" || true

if [[ -z "$TASK_ROW" ]]; then
  echo "❌ لا توجد مهمة بـ id = $TASK_ID في جدول tasks."
  exit 1
fi

echo "----- المهمة قبل التعديل -----"
echo "$TASK_ROW"
echo "-------------------------------"
echo

# استخراج الحالة الحالية
CURRENT_STATUS="$(echo "$TASK_ROW" | awk -F'= ' '/status =/ {print $2}' | tr -d ' ')"

if [[ "$CURRENT_STATUS" == "DONE" ]]; then
  echo "ℹ️ هذه المهمة حالياً في حالة DONE بالفعل – لن يتم أي تعديل."
  exit 0
fi

if [[ "$CURRENT_STATUS" != "PLANNED" && "$CURRENT_STATUS" != "RUNNING" ]]; then
  echo "⚠️ الحالة الحالية ليست PLANNED ولا RUNNING (status=$CURRENT_STATUS)."
  echo "   لأسباب السلامة لن أعدّل هذه المهمة تلقائياً."
  exit 1
fi

echo "هذه المهمة حالياً في حالة: $CURRENT_STATUS"
echo
read -r -p "تأكيد تغيير حالة هذه المهمة إلى DONE ؟ اكتب YES للتأكيد: " ANSWER

if [[ "$ANSWER" != "YES" ]]; then
  echo "🚫 تم الإلغاء – لم يتم أي تعديل."
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S')"

echo
echo "[i] تحديث حالة المهمة في قاعدة البيانات..."
sqlite3 "$TASKS_DB" "UPDATE tasks SET status = 'DONE', updated_at = '$NOW' WHERE id = $TASK_ID;" || {
  echo "❌ فشل تحديث المهمة في قاعدة البيانات."
  exit 1
}

echo
echo "----- المهمة بعد التعديل -----"
sqlite3 -line "$TASKS_DB" "SELECT id, actor, scope, status, priority, title, created_at, updated_at FROM tasks WHERE id = $TASK_ID;"
echo "-------------------------------"

echo
echo "✅ تم تقفيل المهمة رقم $TASK_ID (status = DONE)."
echo "   يمكنك مراجعة الـ Backlog بالكامل بالأمر:"
echo "     tools/hf_tasks_challenge_summary.sh"
