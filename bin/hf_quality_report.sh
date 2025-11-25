#!/usr/bin/env bash
# HyperFFactory – Quality Report (safe)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_QUALITY_DB"

find_quality_table() {
  sqlite3 "$HF_QUALITY_DB" "
    SELECT name FROM sqlite_master
    WHERE type='table'
      AND name IN ('quality_checks','hf_quality_checks','checks','quality')
    LIMIT 1;
  "
}

has_column() {
  local db="$1" table="$2" col="$3"
  sqlite3 "$db" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

QUAL_TABLE="$(find_quality_table)"

if [[ -z "$QUAL_TABLE" ]]; then
  echo "❌ لا يوجد جدول جودة معروف داخل $HF_QUALITY_DB" >&2
  sqlite3 "$HF_QUALITY_DB" ".tables" || true
  exit 1
fi

echo "====================================================="
echo " HyperFFactory – Quality Report"
echo " DB    : $HF_QUALITY_DB"
echo " TABLE : $QUAL_TABLE"
echo " TIME  : $(date +"%Y-%m-%d %H:%M:%S %z")"
echo "====================================================="

echo
echo "📊 Schema:"
sqlite3 "$HF_QUALITY_DB" "PRAGMA table_info($QUAL_TABLE);" | column -t -s'|'

echo
echo "📊 Latest quality rows (last 10, raw):"
sqlite3 -header -column "$HF_QUALITY_DB" "SELECT * FROM $QUAL_TABLE ORDER BY rowid DESC LIMIT 10;"

# Average by target if possible
if has_column "$HF_QUALITY_DB" "$QUAL_TABLE" "target" && has_column "$HF_QUALITY_DB" "$QUAL_TABLE" "score"; then
  echo
  echo "📈 Average score per target:"
  sqlite3 -header -column "$HF_QUALITY_DB" <<SQL
SELECT
  target,
  ROUND(AVG(score), 2) AS avg_score,
  COUNT(*) AS samples
FROM $QUAL_TABLE
GROUP BY target
ORDER BY avg_score DESC;
SQL
fi

# Daily trend if we have score + time column
TIME_COL=""
for c in created_at ts time timestamp; do
  if has_column "$HF_QUALITY_DB" "$QUAL_TABLE" "$c"; then
    TIME_COL="$c"
    break
  fi
done

if [[ -n "$TIME_COL" ]] && has_column "$HF_QUALITY_DB" "$QUAL_TABLE" "score" && has_column "$HF_QUALITY_DB" "$QUAL_TABLE" "target"; then
  echo
  echo "📆 Daily trend (avg score per date/target):"
  sqlite3 -header -column "$HF_QUALITY_DB" <<SQL
SELECT
  substr($TIME_COL, 1, 10) AS day,
  target,
  ROUND(AVG(score), 2) AS avg_score,
  COUNT(*) AS samples
FROM $QUAL_TABLE
GROUP BY day, target
ORDER BY day DESC, target;
SQL
fi
