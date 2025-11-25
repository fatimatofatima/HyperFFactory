#!/usr/bin/env bash
# HF Challenge – Summary of HyperFFactory tasks (PLANNED/DONE) بدون أي تعديل.
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
TASKS_DB="$HYPER_ROOT/db/meta/hf_tasks.db"

cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "====================================================="
echo "HF Challenge – Tasks Summary (hf_tasks.db)"
echo "====================================================="
echo "ROOT : $HYPER_ROOT"
echo "DB   : $TASKS_DB"
echo "TIME : $TS_HUMAN"
echo

if [[ ! -f "$TASKS_DB" ]]; then
  echo "❌ قاعدة المهام غير موجودة: $TASKS_DB"
  exit 1
fi

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

# 1) عدد المهام حسب الحالة
sep "1) عدد المهام حسب الحالة"
sqlite3 "$TASKS_DB" "SELECT status, COUNT(*) FROM tasks GROUP BY status;" || {
  echo "⚠️ خطأ أثناء قراءة عدد المهام من tasks"
}

# 2) أهم المهام PLANNED (أعلى أولوية)
sep "2) المهام PLANNED (Backlog التحدّي)"
sqlite3 -header -column "$TASKS_DB" '
  SELECT
    id,
    actor,
    scope,
    status,
    priority,
    title,
    created_at,
    updated_at
  FROM tasks
  WHERE status = "PLANNED"
  ORDER BY priority ASC, id ASC
;' || {
  echo "⚠️ خطأ أثناء قراءة المهام PLANNED من tasks"
}

# 3) المهام DONE (لسجل ما تمّ تنفيذه)
sep "3) المهام DONE (مراحل مكتملة)"
sqlite3 -header -column "$TASKS_DB" '
  SELECT
    id,
    actor,
    scope,
    status,
    priority,
    title,
    created_at,
    updated_at
  FROM tasks
  WHERE status = "DONE"
  ORDER BY id ASC
;' || {
  echo "⚠️ خطأ أثناء قراءة المهام DONE من tasks"
}

echo
echo "====================================================="
echo "HF Challenge – End of Summary"
echo "====================================================="
