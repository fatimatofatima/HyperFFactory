#!/usr/bin/env bash
# HyperFFactory - Auto update execution status line in README & plan_status
# يركّز فقط على البلوك الخاص بـ "ضرورة تسجيل التقدّم ... حالة التنفيذ: ⏭"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
README="$ROOT_DIR/README.md"
PLAN_STATUS="$ROOT_DIR/plan_status.md"
BACKUP_DIR="$ROOT_DIR/backups/plan_updates"

mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"

echo "=================================================="
echo "📝 HyperFFactory – Auto update execution status"
echo "📍 Root : $ROOT_DIR"
echo "🕒 Time : $TS"
echo "=================================================="

# نسخ احتياطي قبل أي تعديل
if [[ -f "$README" ]]; then
  cp "$README" "$BACKUP_DIR/README_${TS}.before_exec_status.md"
  echo "✅ Backup README  → $BACKUP_DIR/README_${TS}.before_exec_status.md"
else
  echo "⚠️ README.md غير موجود في $ROOT_DIR" >&2
fi

if [[ -f "$PLAN_STATUS" ]]; then
  cp "$PLAN_STATUS" "$BACKUP_DIR/plan_status_${TS}.before_exec_status.md"
  echo "✅ Backup plan_status → $BACKUP_DIR/plan_status_${TS}.before_exec_status.md"
else
  echo "⚠️ plan_status.md غير موجود في $ROOT_DIR" >&2
fi

# فحص المؤشرات الفعلية على السيرفر
HAS_TASKS_DB=0
HAS_PROGRESS_DB=0
HAS_PROGRESS_LOGS=0

[[ -f "$ROOT_DIR/db/meta/hf_tasks.db" ]]    && HAS_TASKS_DB=1
[[ -f "$ROOT_DIR/db/meta/hf_changes.db" ]]  && HAS_PROGRESS_DB=1
ls "$ROOT_DIR"/reports/hf_progress_*.log >/dev/null 2>&1 && HAS_PROGRESS_LOGS=1 || true

echo "🔎 Checks:"
echo "   - hf_tasks.db      : $HAS_TASKS_DB"
echo "   - hf_changes.db    : $HAS_PROGRESS_DB"
echo "   - hf_progress logs : $HAS_PROGRESS_LOGS"

# تحديد الحالة الجديدة بناء على الموجود
if [[ "$HAS_TASKS_DB" -eq 1 && "$HAS_PROGRESS_DB" -eq 1 && "$HAS_PROGRESS_LOGS" -eq 1 ]]; then
  NEW_STATUS="حالة التنفيذ: 🟡 قيد التطبيق (جزئيًا – تسجيل التقدّم فعّال، التفعيل المنهجي مستمر)"
  echo "✅ تم استيفاء شروط التفعيل الجزئي → تعيين الحالة إلى 🟡"
else
  NEW_STATUS="حالة التنفيذ: ⏭ قيد التفعيل المنهجي"
  echo "ℹ️ الشروط غير مكتملة بالكامل → الإبقاء على ⏭"
fi

# تحديث السطر في plan_status.md (السطور التي تبدأ بـ مسافة ومسافة ثم 'حالة التنفيذ:')
if [[ -f "$PLAN_STATUS" ]]; then
  if grep -q '^  حالة التنفيذ:' "$PLAN_STATUS"; then
    sed -i "s/^  حالة التنفيذ: .*/  $NEW_STATUS/" "$PLAN_STATUS"
    echo "✅ تم تحديث سطر حالة التنفيذ في plan_status.md"
  else
    echo "ℹ️ لم يتم العثور على سطر '  حالة التنفيذ:' في plan_status.md (لا تعديل)."
  fi
fi

# تحديث السطر في README.md بنفس النمط
if [[ -f "$README" ]]; then
  if grep -q '^  حالة التنفيذ:' "$README"; then
    sed -i "s/^  حالة التنفيذ: .*/  $NEW_STATUS/" "$README"
    echo "✅ تم تحديث سطر حالة التنفيذ في README.md"
  else
    echo "ℹ️ لم يتم العثور على سطر '  حالة التنفيذ:' في README.md (لا تعديل)."
  fi
fi

echo "=================================================="
echo "✅ hf_plan_update_execution_status.sh انتهى."
echo "=================================================="
