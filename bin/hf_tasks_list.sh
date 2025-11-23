#!/usr/bin/env bash
# HyperFFactory - List Tasks
# Usage:
#   hf_tasks_list.sh [STATUS]
# STATUS اختياري: PLANNED / RUNNING / DONE / FAILED / SKIPPED

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_tasks.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "⚠️ قاعدة hf_tasks.db غير موجودة. شغّل bin/hf_tasks_init.sh أولاً." >&2
  exit 1
fi

status_filter="${1:-}"

sql="SELECT id,actor,scope,status,priority,title,created_at,updated_at FROM tasks"
if [[ -n "$status_filter" ]]; then
  sql="$sql WHERE status = '$(printf "%s" "$status_filter" | sed "s/'/''/g")'"
fi
sql="$sql ORDER BY
        CASE status
          WHEN 'PLANNED' THEN 1
          WHEN 'RUNNING' THEN 2
          WHEN 'FAILED'  THEN 3
          WHEN 'DONE'    THEN 4
          WHEN 'SKIPPED' THEN 5
          ELSE 6
        END,
        priority ASC,
        created_at DESC;"

sqlite3 -header -column "$DB" "$sql"
