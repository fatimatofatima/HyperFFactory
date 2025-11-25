#!/usr/bin/env bash
# HyperFFactory – Sync Tasks from plan_status.md into hf_tasks.db

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB="$META_DIR/hf_tasks.db"
PLAN_FILE="$ROOT/plan_status.md"

if [ ! -f "$DB" ]; then
  echo "❌ لم يتم العثور على $DB" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت على النظام." >&2
  exit 1
fi

if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ لم يتم العثور على ملف الخطة: $PLAN_FILE" >&2
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"
actor="hf_plan"
scope="plan:hyperfactory"

while IFS= read -r line; do
  case "$line" in
    *"✅"*) task_status="DONE" ;;
    *"🟡"*) task_status="RUNNING" ;;
    *"⏭"*) task_status="PLANNED" ;;
    *) continue ;;
  esac

  clean_line=$(printf '%s\n' "$line" | sed -E 's/[✅🟡⏭]//g; s/^[[:space:]-]+//; s/[[:space:]]+$//;')
  [ -z "$clean_line" ] && continue

  title="$clean_line"
  safe_title=${title//\'/\'\'}

  sqlite3 "$DB" <<SQL
-- تحديث إن وجد
UPDATE tasks
   SET status     = '$task_status',
       updated_at = '$NOW'
 WHERE actor = '$actor'
   AND title = '$safe_title';

-- إنشاء إن لم يكن موجودًا
INSERT INTO tasks (actor,scope,status,priority,title,created_at,updated_at)
SELECT '$actor', '$scope', '$task_status', 80, '$safe_title', '$NOW', '$NOW'
WHERE NOT EXISTS (
  SELECT 1 FROM tasks
  WHERE actor = '$actor'
    AND title = '$safe_title'
);
SQL

done < "$PLAN_FILE"

echo "✅ تم مزامنة المهام مع plan_status.md داخل hf_tasks.db."
