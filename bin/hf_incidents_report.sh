#!/usr/bin/env bash
# HyperFFactory – Incidents Report (safe)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_ERRORS_DB"

find_errors_table() {
  sqlite3 "$HF_ERRORS_DB" "
    SELECT name FROM sqlite_master
    WHERE type='table'
      AND name IN ('errors','hf_errors','incidents')
    LIMIT 1;
  "
}

has_column() {
  local db="$1" table="$2" col="$3"
  sqlite3 "$db" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

ERR_TABLE="$(find_errors_table)"

if [[ -z "$ERR_TABLE" ]]; then
  echo "❌ لا يوجد جدول أخطاء (errors / hf_errors / incidents) داخل $HF_ERRORS_DB" >&2
  sqlite3 "$HF_ERRORS_DB" ".tables" || true
  exit 1
fi

echo "====================================================="
echo " HyperFFactory – Incidents Report"
echo " DB    : $HF_ERRORS_DB"
echo " TABLE : $ERR_TABLE"
echo " TIME  : $(date +"%Y-%m-%d %H:%M:%S %z")"
echo "====================================================="

echo
echo "📊 Schema:"
sqlite3 "$HF_ERRORS_DB" "PRAGMA table_info($ERR_TABLE);" | column -t -s'|'

echo
echo "📊 Latest incidents (last 20, raw):"
sqlite3 -header -column "$HF_ERRORS_DB" "SELECT * FROM $ERR_TABLE ORDER BY rowid DESC LIMIT 20;"

# Summary by severity if exists
if has_column "$HF_ERRORS_DB" "$ERR_TABLE" "severity"; then
  echo
  echo "📈 Summary by severity:"
  sqlite3 -header -column "$HF_ERRORS_DB" <<SQL
SELECT
  severity,
  COUNT(*) AS count
FROM $ERR_TABLE
GROUP BY severity
ORDER BY count DESC;
SQL
fi

# Open incidents if state موجود
if has_column "$HF_ERRORS_DB" "$ERR_TABLE" "state"; then
  echo
  echo "📋 Open incidents (state IS NULL or OPEN):"
  sqlite3 -header -column "$HF_ERRORS_DB" <<SQL
SELECT *
FROM $ERR_TABLE
WHERE state IS NULL OR state='OPEN'
ORDER BY rowid DESC;
SQL
fi
