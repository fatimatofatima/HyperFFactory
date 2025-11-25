#!/usr/bin/env bash
# HyperFFactory – DB Shadow / Core Audit (READ-ONLY)
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || { echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"; exit 1; }

echo "=================================================="
echo " HyperFFactory – DB Shadow / Core Audit (READ-ONLY)"
echo " ROOT: $HYPER_ROOT"
echo " TIME: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "=================================================="
echo

CORE_DBS=(
  "db/meta/hf_tasks.db"
  "db/meta/hf_quality.db"
  "db/meta/hf_learning.db"
  "db/meta/hf_errors.db"
  "db/meta/hf_changes.db"
  "db/meta/hf_ops_meta.db"
)

SHADOW_DBS=(
  "db/tasks/tasks.db"
  "db/quality.db"
  "var/db/management/tasks.db"
  "var/db/management/quality.db"
  "var/db/management/workers.db"
)

inspect_db() {
  local label="$1"
  local path="$2"

  echo "--------------------------------------------------"
  echo "[$label] $path"
  if [[ ! -f "$path" ]]; then
    echo "  ↳ الحالة: MISSING (الملف غير موجود)"
    return
  fi

  local size
  size=$(stat -c '%s' "$path" 2>/dev/null || echo "?")
  echo "  ↳ الحجم: $size bytes"

  # integrity_check
  local integrity
  integrity=$(sqlite3 "$path" 'PRAGMA integrity_check;' 2>/dev/null || echo "error")
  echo "  ↳ integrity_check: $integrity"

  echo "  ↳ الجداول:"
  sqlite3 "$path" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null \
    | sed 's/^/     - /' || echo "     (لا توجد جداول)"

  for t in tasks quality_checks quality_events quality_metrics quality_runs workers errors learning learning_events lessons_learned; do
    local cnt
    cnt=$(sqlite3 "$path" "SELECT COUNT(*) FROM $t;" 2>/dev/null || echo "")
    if [[ -n "$cnt" ]]; then
      echo "  ↳ عدد الصفوف في $t: $cnt"
    fi
  done
}

echo "************ CORE META DBS (المصدر الرسمي) ************"
for db in "${CORE_DBS[@]}"; do
  inspect_db "CORE" "$db"
done

echo
echo "*********** SHADOW / MGMT DBS (للمراجعة) ***********"
for db in "${SHADOW_DBS[@]}"; do
  inspect_db "SHADOW" "$db"
done

echo
echo "=================================================="
echo " انتهى الفحص بدون أي تعديل على قواعد البيانات."
echo " استخدم هذا التقرير لاتخاذ قرار الدمج / الأرشفة لاحقًا."
echo "=================================================="
