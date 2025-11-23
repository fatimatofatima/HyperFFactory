#!/usr/bin/env bash
# HyperFFactory - Tasks Summary Report

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

echo "=================================================="
echo "📋 HyperFFactory – Tasks Report"
echo "📍 Root : $ROOT_DIR"
echo "🕒 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
echo

echo "1) Summary by Status"
echo "----------------------------------------"
sqlite3 -header -column "$DB" "
  SELECT status, COUNT(*) AS count
  FROM tasks
  GROUP BY status
  ORDER BY
    CASE status
      WHEN 'PLANNED' THEN 1
      WHEN 'RUNNING' THEN 2
      WHEN 'FAILED'  THEN 3
      WHEN 'DONE'    THEN 4
      WHEN 'SKIPPED' THEN 5
      ELSE 6
    END;
"
echo

echo "2) Top 10 Open Tasks (PLANNED/RUNNING)"
echo "----------------------------------------"
sqlite3 -header -column "$DB" "
  SELECT id,actor,scope,status,priority,title,created_at
  FROM tasks
  WHERE status IN ('PLANNED','RUNNING')
  ORDER BY priority ASC, created_at ASC
  LIMIT 10;
"
echo

echo "=================================================="
echo "✅ Tasks report انتهى."
echo "=================================================="
