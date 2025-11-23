#!/usr/bin/env bash
# HyperFFactory - Progress Logger
# يسجّل أي خطوة مهمّة في:
# 1) قاعدة db/meta/hf_changes.db
# 2) ملف تقارير يومي في reports/hf_progress_YYYYMMDD.log

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
REPORT_DIR="$ROOT_DIR/reports"

mkdir -p "$META_DIR" "$REPORT_DIR"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <actor> <status> [message]" >&2
  echo "مثال: $0 hyper_brain_controller START \"بدء فحص شامل\"" >&2
  exit 1
fi

ACTOR="$1"      # اسم المدير/الخدمة: hyper_brain_controller, hyper_check_all_dbs, ...
STATUS="$2"     # START / INFO / WARN / DONE / FAIL ...
shift 2
MSG="${*:-}"    # رسالة اختيارية

TS="$(date '+%Y-%m-%d %H:%M:%S')"
DAY_FILE="$REPORT_DIR/hf_progress_$(date +%Y%m%d).log"
DB="$META_DIR/hf_changes.db"

# إنشاء جدول التغييرات إذا لم يكن موجودًا
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS changes (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  ts      TEXT    NOT NULL,
  actor   TEXT    NOT NULL,
  status  TEXT    NOT NULL,
  message TEXT,
  source  TEXT,
  extra   TEXT
);
SQL

# تحضير القيم مع هروب بسيط لعَلامة '
ESC_TS="${TS//\'/\'\'}"
ESC_ACTOR="${ACTOR//\'/\'\'}"
ESC_STATUS="${STATUS//\'/\'\'}"
ESC_MSG="${MSG//\'/\'\'}"
SOURCE_PATH="$(pwd)"
ESC_SOURCE="${SOURCE_PATH//\'/\'\'}"

sqlite3 "$DB" "INSERT INTO changes (ts,actor,status,message,source,extra) VALUES ('$ESC_TS','$ESC_ACTOR','$ESC_STATUS','$ESC_MSG','$ESC_SOURCE','');"

echo "$TS | actor=$ACTOR | status=$STATUS | $MSG" >> "$DAY_FILE"

echo "✅ Progress logged: $ACTOR [$STATUS]"
echo "   - DB : $DB"
echo "   - LOG: $DAY_FILE"
