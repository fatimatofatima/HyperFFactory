#!/usr/bin/env bash
# HyperFFactory - Add Error Record
# Usage:
#   hf_errors_add.sh <actor> <error_type> <severity> <error_message> [context]
# severity ∈ {LOW,MEDIUM,HIGH,CRITICAL}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_errors.db"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <actor> <error_type> <severity> <error_message> [context]" >&2
  exit 1
fi

ACTOR="$1"
ERROR_TYPE="$2"
SEVERITY="$3"
ERROR_MESSAGE="$4"
shift 4 || true
CONTEXT="${*:-}"

case "$SEVERITY" in
  LOW|MEDIUM|HIGH|CRITICAL) ;;
  *)
    echo "❌ Severity غير صالح (LOW/MEDIUM/HIGH/CRITICAL): $SEVERITY" >&2
    exit 1
    ;;
esac

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "❌ hf_errors.db غير موجود. شغّل hf_errors_init.sh أولاً." >&2
  exit 1
fi

TS="$(date '+%Y-%m-%d %H:%M:%S')"

sqlite3 "$DB" <<SQL
INSERT INTO errors (actor,error_type,error_message,severity,context,ts)
VALUES (
  '$ACTOR',
  '$ERROR_TYPE',
  '$ERROR_MESSAGE',
  '$SEVERITY',
  '$CONTEXT',
  '$TS'
);
SQL

echo "✅ تم تسجيل الخطأ: $ERROR_TYPE ($SEVERITY)"

PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_errors_add" "WARN" "actor=$ACTOR type=$ERROR_TYPE severity=$SEVERITY"
fi

exit 0
