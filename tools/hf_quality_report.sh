#!/usr/bin/env bash
# HyperFFactory – Quality KPI Report (Summary)

set -euo pipefail

ROOT="/root/HyperFFactory"
QUALITY_DB="$ROOT/db/meta/hf_quality.db"

cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير متوفر."
  exit 1
fi

echo "=================================================="
echo "🧩 HyperFFactory – Quality KPI Summary"
echo "DB : $QUALITY_DB"
echo "=================================================="

sqlite3 -header -column "$QUALITY_DB" <<'SQL'
SELECT
  system_name,
  metric_name,
  ROUND(AVG(metric_value), 3) AS avg_value,
  COUNT(*) AS samples,
  MAX(window_label) AS last_window,
  MAX(created_at)  AS last_record
FROM quality_events
GROUP BY system_name, metric_name
ORDER BY system_name, metric_name;
SQL
