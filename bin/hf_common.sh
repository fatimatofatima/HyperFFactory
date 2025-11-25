#!/usr/bin/env bash
set -euo pipefail

# الجذر (HyperFFactory/) من موقع السكربت نفسه
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
META_DB_DIR="$ROOT_DIR/db/meta"

HF_TASKS_DB="$META_DB_DIR/hf_tasks.db"
HF_ERRORS_DB="$META_DB_DIR/hf_errors.db"
HF_QUALITY_DB="$META_DB_DIR/hf_quality.db"
HF_ACTORS_DB="$META_DB_DIR/hf_actors.db"
HF_CHANGES_DB="$META_DB_DIR/hf_changes.db"

ts_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

require_db() {
  local db="$1"
  if [[ ! -f "$db" ]]; then
    echo "❌ Database not found: $db" >&2
    exit 1
  fi
}
