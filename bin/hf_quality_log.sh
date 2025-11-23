#!/usr/bin/env bash
# HyperFFactory - Log Quality Check
# Usage:
#   hf_quality_log.sh <actor> <check_name> <scope> <result> <score> [details...]
#
#   result ∈ {PASS, FAIL, WARN, SKIP}
#   score  ∈ 0–100 (رقم صحيح)
#   details نص حر (اختياري)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_quality.db"
INIT="$ROOT_DIR/bin/hf_quality_init.sh"
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  if [[ -x "$INIT" ]]; then
    "$INIT"
  else
    echo "⚠️ قاعدة hf_quality.db غير موجودة ولا يوجد hf_quality_init.sh." >&2
    exit 1
  fi
fi

if [[ $# -lt 5 ]]; then
  echo "Usage: $(basename "$0") <actor> <check_name> <scope> <result> <score> [details...]" >&2
  exit 1
fi

actor="$1"
check_name="$2"
scope="$3"
result="$4"
score_raw="$5"
shift 5
details="${*:-}"

case "$result" in
  PASS|FAIL|WARN|SKIP) ;;
  *)
    echo "⚠️ result غير معروف: $result (يفترض: PASS/FAIL/WARN/SKIP)" >&2
    ;;
esac

# تحويل score إلى رقم صحيح
if [[ -z "$score_raw" ]]; then
  score=0
elif ! [[ "$score_raw" =~ ^-?[0-9]+$ ]]; then
  echo "⚠️ score '$score_raw' ليس رقمًا صحيحًا، سيتم تخزينه كـ 0" >&2
  score=0
else
  score="$score_raw"
fi

ts="$(date '+%Y-%m-%d %H:%M:%S')"

esc() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql="
INSERT INTO quality_checks (actor,check_name,scope,result,score,details,ts)
VALUES (
  '$(esc "$actor")',
  '$(esc "$check_name")',
  '$(esc "$scope")',
  '$(esc "$result")',
  $score,
  '$(esc "$details")',
  '$(esc "$ts")'
);
"

sqlite3 "$DB" "$sql"

if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_quality_log" "INFO" "actor=$actor scope=$scope result=$result score=$score"
fi

echo "✅ تم تسجيل فحص جودة جديد في $DB"
