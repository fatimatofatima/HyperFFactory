#!/usr/bin/env bash
# HyperFFactory – Log Error Incident into hf_errors.db
#
# الاستخدام:
#   hf_log_incident.sh "actor" "error_type" "severity" "error_message" "context" [exit_code] [ref_report_path]
#
# الأمثلة:
#   hf_log_incident.sh "Stage9:DB_AUDIT" "SCRIPT_FAILURE" "HIGH" "hf_db_audit.sh failed" "ROOT=/root/HyperFFactory" 1 "/root/HyperFFactory/reports/..."
#

set -euo pipefail

ROOT="${HF_ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_ERRORS="$META_DIR/hf_errors.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت: apt-get update && apt-get install -y sqlite3"
  exit 1
fi

if [ $# -lt 4 ]; then
  echo "❌ استخدام غير صحيح."
  echo "Usage: $0 \"actor\" \"error_type\" \"severity\" \"error_message\" \"context\" [exit_code] [ref_report_path]"
  exit 1
fi

ACTOR="$1"
ERR_TYPE="$2"
SEVERITY="$3"
ERR_MSG="$4"
CONTEXT="${5:-}"
EXIT_CODE="${6:-NULL}"
REF_REPORT_PATH="${7:-}"

case "$SEVERITY" in
  LOW|MEDIUM|HIGH|CRITICAL) ;;
  *)
    echo "⚠️ severity غير معروف: $SEVERITY – سيتم تعيينه إلى MEDIUM"
    SEVERITY="MEDIUM"
    ;;
esac

NOW_TS="$(date '+%Y-%m-%d %H:%M:%S %z')"
CREATED_AT="$NOW_TS"
SOURCE_SCRIPT="${HF_SOURCE_SCRIPT:-${0##*/}}"

mkdir -p "$META_DIR"
/usr/bin/env bash "$ROOT/tools/hf_errors_schema_upgrade.sh" "$ROOT" >/dev/null 2>&1 || true

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

ACTOR_E="$(sql_escape "$ACTOR")"
ERR_TYPE_E="$(sql_escape "$ERR_TYPE")"
SEVERITY_E="$(sql_escape "$SEVERITY")"
ERR_MSG_E="$(sql_escape "$ERR_MSG")"
CONTEXT_E="$(sql_escape "$CONTEXT")"
SOURCE_E="$(sql_escape "$SOURCE_SCRIPT")"
REPORT_E="$(sql_escape "$REF_REPORT_PATH")"
TS_E="$(sql_escape "$NOW_TS")"
CREATED_E="$(sql_escape "$CREATED_AT")"

if [ "$EXIT_CODE" = "NULL" ]; then
  EXIT_CODE_SQL="NULL"
else
  EXIT_CODE_SQL="$EXIT_CODE"
fi

sqlite3 "$DB_ERRORS" <<SQL
INSERT INTO incidents (
  actor,
  error_type,
  error_message,
  severity,
  ts,
  context,
  source_script,
  exit_code,
  ref_change_id,
  ref_report_path,
  created_at
) VALUES (
  '$ACTOR_E',
  '$ERR_TYPE_E',
  '$ERR_MSG_E',
  '$SEVERITY_E',
  '$TS_E',
  '$CONTEXT_E',
  '$SOURCE_E',
  $EXIT_CODE_SQL,
  NULL,
  '$REPORT_E',
  '$CREATED_E'
);
SQL

echo "✅ Incident مسجّل في hf_errors.db:"
echo "   actor=$ACTOR, type=$ERR_TYPE, severity=$SEVERITY, exit_code=$EXIT_CODE"
