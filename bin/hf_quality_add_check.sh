#!/usr/bin/env bash
# HyperFFactory - Add Quality Check
# Usage:
#   hf_quality_add_check.sh <actor> <scope> <check_name> <result> <score_or_- > [details]
# result ∈ {PASS,FAIL,WARN}
# score  ∈ 0–100 أو '-' لتركه فارغًا

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_quality.db"

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <actor> <scope> <check_name> <result> <score_or_-> [details]" >&2
  exit 1
fi

ACTOR="$1"
SCOPE="$2"
CHECK_NAME="$3"
RESULT="$4"
SCORE_IN="$5"
shift 5 || true
DETAILS="${*:-}"

case "$RESULT" in
  PASS|FAIL|WARN) ;;
  *)
    echo "❌ نتيجة غير صالحة (PASS/FAIL/WARN فقط): $RESULT" >&2
    exit 1
    ;;
esac

if [[ "$SCORE_IN" = "-" ]]; then
  SCORE_SQL="NULL"
else
  if ! [[ "$SCORE_IN" =~ ^[0-9]+$ ]]; then
    echo "❌ score يجب أن يكون رقمًا (0–100) أو '-'." >&2
    exit 1
  fi
  SCORE_SQL="$SCORE_IN"
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "❌ hf_quality.db غير موجود. شغّل hf_quality_init.sh أولاً." >&2
  exit 1
fi

TS="$(date '+%Y-%m-%d %H:%M:%S')"

sqlite3 "$DB" <<SQL
INSERT INTO quality_checks (actor,check_name,scope,result,score,details,ts)
VALUES (
  '$ACTOR',
  '$CHECK_NAME',
  '$SCOPE',
  '$RESULT',
  $SCORE_SQL,
  '$DETAILS',
  '$TS'
);
SQL

echo "✅ تم تسجيل فحص الجودة: $CHECK_NAME ($RESULT)"

PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_quality_add_check" "INFO" "actor=$ACTOR scope=$SCOPE check=$CHECK_NAME result=$RESULT"
fi

exit 0
