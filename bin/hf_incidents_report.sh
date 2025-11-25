#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_ERRORS_DB"

echo "📊 Incidents summary by actor/scope/state:"
sqlite3 -header -column "$HF_ERRORS_DB" <<'SQL'
SELECT
  actor,
  scope,
  severity,
  COALESCE(state, 'OPEN') AS state,
  COUNT(*) AS count
FROM errors
GROUP BY actor, scope, severity, state
ORDER BY count DESC, severity DESC, actor ASC;
SQL

echo
echo "📋 Open incidents (state IS NULL or OPEN):"
sqlite3 -header -column "$HF_ERRORS_DB" <<'SQL'
SELECT
  id,
  actor,
  scope,
  severity,
  COALESCE(state, 'OPEN') AS state,
  ts AS created_at
FROM errors
WHERE state IS NULL OR state = 'OPEN'
ORDER BY ts DESC, id DESC
LIMIT 20;
SQL
