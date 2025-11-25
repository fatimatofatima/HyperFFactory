#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_DIR="$ROOT/db"

TASKS_DB="$META_DIR/hf_tasks.db"

echo "====================================================="
echo " HyperFFactory – Tasks Registry Diag"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " DB   : $TASKS_DB"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="

echo
echo "[1] hf_tasks.db file status:"
if [ -f "$TASKS_DB" ]; then
  ls -lh "$TASKS_DB"
else
  echo "  ⚠️  hf_tasks.db does NOT exist yet."
fi

echo
echo "[2] Tables inside hf_tasks.db (if file exists):"
if [ -f "$TASKS_DB" ]; then
  sqlite3 "$TASKS_DB" "SELECT name FROM sqlite_master WHERE type='table';" || \
    echo "  ⚠️  sqlite3 error while listing tables."
else
  echo "  (skip – file not found)"
fi

echo
echo "[3] Search for any DB that already has table 'hf_tasks' under db/ and db/meta/:"
find "$DB_DIR" -maxdepth 3 -type f -name '*.db' | while read -r db; do
  HAS_TABLE="$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='hf_tasks';" 2>/dev/null || echo 0)"
  if [ "$HAS_TABLE" != "0" ] && [ "$HAS_TABLE" != "" ]; then
    echo "  ✅ Found hf_tasks table in: $db"
    sqlite3 "$db" "PRAGMA table_info(hf_tasks);"
  fi
done

echo
echo "====================================================="
echo " Diag finished."
echo "====================================================="
