#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

DB="$HF_TASKS_DB"
META_DIR="$(dirname "$DB")"

echo "====================================================="
echo " HyperFFactory – Ensure hf_tasks schema"
echo " DB   : $DB"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="

mkdir -p "$META_DIR"

if [ ! -f "$DB" ]; then
  echo "[INFO] hf_tasks.db does NOT exist – creating empty file..."
  : > "$DB"
fi

HAS_TABLE="$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='hf_tasks';" 2>/dev/null || echo 0)"

if [ "$HAS_TABLE" != "0" ] && [ "$HAS_TABLE" != "" ]; then
  echo "[OK] Table 'hf_tasks' already exists in $DB – will not modify schema."
  echo "[INFO] Current schema:"
  sqlite3 "$DB" "PRAGMA table_info(hf_tasks);"
  echo "====================================================="
  exit 0
fi

echo "[WARN] Table 'hf_tasks' is missing in $DB – creating registry table and indexes..."

sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS hf_tasks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT NOT NULL,
  scope      TEXT NOT NULL,
  status     TEXT NOT NULL,
  priority   INTEGER NOT NULL DEFAULT 0,
  title      TEXT,
  tags       TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hf_tasks_actor_status
  ON hf_tasks (actor, status);

CREATE INDEX IF NOT EXISTS idx_hf_tasks_scope_status
  ON hf_tasks (scope, status);

CREATE INDEX IF NOT EXISTS idx_hf_tasks_priority_status
  ON hf_tasks (priority, status);
SQL

echo "[OK] Table 'hf_tasks' + indexes created."
echo "[INFO] New schema:"
sqlite3 "$DB" "PRAGMA table_info(hf_tasks);"

echo "====================================================="
echo " Done."
echo "====================================================="
