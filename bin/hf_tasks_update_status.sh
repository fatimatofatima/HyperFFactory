#!/usr/bin/env bash
# HyperFFactory - Update Task Status
# Usage:
#   hf_tasks_update_status.sh <task_id> <new_status>
# new_status ∈ {PLANNED,RUNNING,DONE,FAILED,SKIPPED}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_tasks.db"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <task_id> <new_status>" >&2
  exit 1
fi

TASK_ID="$1"
NEW_STATUS="$2"

case "$NEW_STATUS" in
  PLANNED|RUNNING|DONE|FAILED|SKIPPED) ;;
  *)
    echo "❌ حالة غير مسموح بها: $NEW_STATUS" >&2
    exit 1
    ;;
esac

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "❌ قاعدة بيانات المهام غير موجودة: $DB" >&2
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S')"

sqlite3 "$DB" <<SQL
UPDATE tasks
SET status = '$NEW_STATUS',
    updated_at = '$NOW'
WHERE id = $TASK_ID;
SQL

echo "✅ تم تحديث الحالة للمهمة رقم: $TASK_ID → $NEW_STATUS"

PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_tasks_update_status" "INFO" "task_id=$TASK_ID status=$NEW_STATUS"
fi

exit 0
