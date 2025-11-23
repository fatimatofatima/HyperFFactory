#!/usr/bin/env bash
# HyperFFactory - Add Quality Check
# Usage:
#   hf_quality_add.sh <actor> <check_name> <result> <score> [details...]
#
# مثال:
#   hf_quality_add.sh hf_health_all smartfriend_services PASS 95 "جميع خدمات السيوت في حالة جيدة"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
REPORT_DIR="$ROOT_DIR/reports"
DB="$META_DIR/hf_quality.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

if [[ ! -f "${DB}" ]]; then
  echo "⚠️ قاعدة بيانات الجودة غير موجودة: ${DB}" >&2
  echo "▶ شغّل أولاً: bin/hf_quality_init.sh" >&2
  exit 1
fi

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <actor> <check_name> <result> <score> [details...]" >&2
  exit 1
fi

actor="$1"
check_name="$2"
result="$3"
score="$4"
shift 4
details="${*:-}"

# التحقق من score رقم بين 0 و 100
if ! [[ "${score}" =~ ^[0-9]+$ ]]; then
  echo "❌ score يجب أن يكون رقمًا صحيحًا بين 0 و 100." >&2
  exit 1
fi

if (( score < 0 || score > 100 )); then
  echo "❌ score خارج النطاق 0–100: ${score}" >&2
  exit 1
fi

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
TS_DAY="$(date +%Y%m%d)"
LOG_FILE="$REPORT_DIR/hf_progress_${TS_DAY}.log"

# هروب بسيط لعلامة '
esc_actor="${actor//\'/''}"
esc_check_name="${check_name//\'/''}"
esc_result="${result//\'/''}"
esc_details="${details//\'/''}"

sqlite3 "${DB}" <<SQL
INSERT INTO quality_checks (actor, check_name, result, score, details, tags, ts)
VALUES ('${esc_actor}', '${esc_check_name}', '${esc_result}', ${score}, '${esc_details}', NULL, '${TS_HUMAN}');
SQL

# جلب آخر id (للتقرير فقط)
last_id="$(sqlite3 "${DB}" 'SELECT max(id) FROM quality_checks;')"

echo "✅ تم تسجيل فحص جودة جديد:"
echo "   id         : ${last_id}"
echo "   actor      : ${actor}"
echo "   check_name : ${check_name}"
echo "   result     : ${result}"
echo "   score      : ${score}"
echo "   ts         : ${TS_HUMAN}"

{
  echo "[${TS_HUMAN}] hf_quality_add [INFO] id=${last_id} actor=${actor} check=${check_name} result=${result} score=${score}"
} >> "${LOG_FILE}"

echo "✅ Progress logged: hf_quality_add [INFO]"
echo "   - LOG: ${LOG_FILE}"
