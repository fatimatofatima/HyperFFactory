#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_ACTORS_DB"

sqlite3 "$HF_ACTORS_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS hf_training_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT NOT NULL,
  session_type TEXT,
  description TEXT,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  outcome TEXT,
  notes TEXT
);
SQL

echo "✅ Table hf_training_sessions ready in $HF_ACTORS_DB"
