#!/usr/bin/env bash
# HyperFFactory – Tasks Admin (Mark Status)
# إدارة حالة المهام في hf_tasks.db:
#   PLANNED / RUNNING / DONE / FAILED
#
# استخدام:
#   bash tools/hf_tasks_mark.sh <TASK_ID> <STATUS>

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
DB_TASKS="$ROOT/db/meta/hf_tasks.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

usage() {
  cat <<USAGE
Usage:
  $0 <TASK_ID> <STATUS>

STATUS ∈ {PLANNED, RUNNING, DONE, FAILED}
مثال:
  $0 21 RUNNING
  $0 21 DONE
USAGE
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage
fi

TASK_ID="$1"
NEW_STATUS="$2"

case "$NEW_STATUS" in
  PLANNED|RUNNING|DONE|FAILED) ;;
  *)
    echo "ERROR: حالة غير صحيحة: $NEW_STATUS" >&2
    usage
    ;;
esac

if [[ ! -f "$DB_TASKS" ]]; then
  echo "ERROR: hf_tasks.db غير موجود: $DB_TASKS" >&2
  exit 1
fi

NOW="$(ts)"

echo "====================================================="
echo " HyperFFactory – Tasks Mark"
echo " DB    : $DB_TASKS"
echo " TASK  : $TASK_ID"
echo " STATUS: $NEW_STATUS"
echo " TIME  : $NOW"
echo "====================================================="

sqlite3 "$DB_TASKS" <<SQL
UPDATE tasks
SET status = '$NEW_STATUS',
    updated_at = '$NOW'
WHERE id = $TASK_ID;
SQL

echo "[INFO] بعد التحديث:"
sqlite3 "$DB_TASKS" <<SQL
.headers on
.mode column
SELECT id, actor, scope, status, priority, title, created_at, updated_at
FROM tasks
WHERE id = $TASK_ID;
SQL
