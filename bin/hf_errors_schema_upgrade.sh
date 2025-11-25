#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_ERRORS_DB"

has_column() {
  local db="$1" table="$2" col="$3"
  sqlite3 "$db" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

TABLE="errors"

echo "🔧 Upgrading schema for $HF_ERRORS_DB :: table=$TABLE"

if ! has_column "$HF_ERRORS_DB" "$TABLE" "state"; then
  sqlite3 "$HF_ERRORS_DB" "ALTER TABLE $TABLE ADD COLUMN state TEXT DEFAULT 'OPEN';"
  echo "  ➕ Added column: state"
fi

if ! has_column "$HF_ERRORS_DB" "$TABLE" "resolved_at"; then
  sqlite3 "$HF_ERRORS_DB" "ALTER TABLE $TABLE ADD COLUMN resolved_at TEXT;"
  echo "  ➕ Added column: resolved_at"
fi

if ! has_column "$HF_ERRORS_DB" "$TABLE" "task_id"; then
  sqlite3 "$HF_ERRORS_DB" "ALTER TABLE $TABLE ADD COLUMN task_id INTEGER;"
  echo "  ➕ Added column: task_id"
fi

echo "✅ Schema upgrade completed."
