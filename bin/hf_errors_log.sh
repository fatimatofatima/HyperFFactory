#!/usr/bin/env bash
# HyperFFactory - Errors Log
# Usage:
#   hf_errors_log.sh <actor> <error_type> <severity> <error_message> <context>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_errors.db"

ERRORS_INIT="$ROOT_DIR/bin/hf_errors_init.sh"
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  if [[ -x "$ERRORS_INIT" ]]; then
    "$ERRORS_INIT"
  else
    echo "❌ hf_errors.db غير موجود و hf_errors_init.sh غير متاح." >&2
    exit 1
  fi
fi

if [[ $# -lt 5 ]]; then
  echo "Usage: $(basename "$0") <actor> <error_type> <severity> <error_message> <context>" >&2
  exit 1
fi

actor="$1"
error_type="$2"
severity="$3"
error_message="$4"
context="$5"

case "$severity" in
  LOW|MEDIUM|HIGH|CRITICAL) ;;
  *)
    echo "⚠️ severity غير معروف: $severity (يفترض: LOW/MEDIUM/HIGH/CRITICAL)" >&2
    ;;
esac

ts="$(date '+%Y-%m-%d %H:%M:%S')"

esc() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql="
INSERT INTO errors (actor,error_type,error_message,severity,context,ts)
VALUES (
  '$(esc "$actor")',
  '$(esc "$error_type")',
  '$(esc "$error_message")',
  '$(esc "$severity")',
  '$(esc "$context")',
  '$(esc "$ts")'
);
"

sqlite3 "$DB" "$sql"

if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_errors_log" "INFO" "actor=$actor type=$error_type severity=$severity"
fi

echo "✅ تم تسجيل خطأ جديد في $DB"
