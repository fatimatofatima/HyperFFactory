#!/usr/bin/env bash
# HyperFFactory – Tasks Overview (hf_ops_meta.tasks)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB="$ROOT/db/meta/hf_ops_meta.db"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$REPORT_DIR/hf_tasks_overview_${TS}.txt"

{
  echo "====================================================="
  echo "HyperFFactory – Tasks Overview (hf_ops_meta.tasks)"
  echo "ROOT : $ROOT"
  echo "DB   : $DB"
  echo "TIME : $TS"
  echo "====================================================="
  echo

  if [ ! -f "$DB" ]; then
    echo "❌ لم يتم العثور على قاعدة البيانات: $DB"
    exit 1
  fi

  echo "== Schema (tasks) =="
  sqlite3 "$DB" 'PRAGMA table_info(tasks);'
  echo

  echo "== Counters by STATUS =="
  sqlite3 "$DB" "
    SELECT status, COUNT(*) AS cnt
    FROM tasks
    GROUP BY status
    ORDER BY status;
  "
  echo

  echo "== Tasks by STAGE / CATEGORY =="
  sqlite3 "$DB" "
    SELECT stage, category, COUNT(*) AS cnt
    FROM tasks
    GROUP BY stage, category
    ORDER BY stage, category;
  "
  echo

  echo "== Sample Tasks (plan_ref, code, title, status, owner) =="
  sqlite3 "$DB" "
    SELECT id, plan_ref, code, title, status, owner
    FROM tasks
    ORDER BY id
    LIMIT 30;
  "
  echo
} | tee "$OUT"

echo
echo "-----------------------------------------------------"
echo "[INFO] Report written to:"
echo "  $OUT"
echo "-----------------------------------------------------"
