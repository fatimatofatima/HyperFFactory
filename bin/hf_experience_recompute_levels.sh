#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_ACTORS_DB"

echo "🔁 Recomputing experience_level in hf_actor_stats ..."

sqlite3 "$HF_ACTORS_DB" <<'SQL'
UPDATE hf_actor_stats
SET experience_level = CASE
  WHEN runs_total IS NULL OR runs_total <= 2 THEN 'NEW'
  WHEN runs_total BETWEEN 3 AND 9 AND success_rate >= 80.0 THEN 'NOVICE'
  WHEN runs_total BETWEEN 10 AND 29 AND success_rate >= 85.0 THEN 'STABLE'
  WHEN runs_total >= 30 AND success_rate >= 90.0 THEN 'EXPERT'
  ELSE COALESCE(experience_level, 'NEW')
END;
SQL

echo "✅ experience_level updated in hf_actor_stats"
