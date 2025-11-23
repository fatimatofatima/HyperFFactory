#!/usr/bin/env bash
# HyperFFactory - Learning Layer: DB-based learning report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
REPORT_DIR="$ROOT_DIR/reports"

DB="$META_DIR/hf_learning.db"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$REPORT_DIR/hf_learning_db_report_${TS}.log"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$DB" ]]; then
  echo "❌ قاعدة التعلّم غير موجودة: $DB" >&2
  echo "   شغّل: bin/hf_learn_to_db.sh" >&2
  exit 1
fi

{
  echo "=================================================="
  echo "🧠 HYPERFFACTORY LEARNING LAYER – DB VIEW"
  echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "📂 Root : $ROOT_DIR"
  echo "📄 DB   : $DB"
  echo "=================================================="
  echo

  echo "1) إجمالي السكربتات:"
  sqlite3 "$DB" "SELECT COUNT(*) FROM scripts;" | awk '{print "   - total scripts : " $1}'
  echo

  echo "2) توزيع السكربتات حسب النظام:"
  sqlite3 -csv "$DB" "SELECT system, COUNT(*) AS cnt FROM scripts GROUP BY system ORDER BY cnt DESC;" \
    | awk -F',' '{printf "   - %s : %s\n", $1, $2}'
  echo

  echo "3) المدراء مقابل العمال:"
  sqlite3 -csv "$DB" "SELECT role, COUNT(*) AS cnt FROM scripts GROUP BY role ORDER BY cnt DESC;" \
    | awk -F',' '{printf "   - %s : %s\n", $1, $2}'
  echo

  echo "4) توزيع الفئات (system/category):"
  sqlite3 -csv "$DB" "
    SELECT system || '/' || category AS key, COUNT(*) AS cnt
    FROM scripts
    GROUP BY system, category
    ORDER BY cnt DESC, key;
  " | awk -F',' '{printf "   - %s : %s\n", $1, $2}'
  echo

  echo "5) أهم المدراء (priority <= 2) مرتّبين حسب النظام والأولوية:"
  echo "   system | priority | role | name | path"
  sqlite3 -csv "$DB" "
    SELECT system, priority, role, name, path
    FROM scripts
    WHERE role='manager' AND priority <= 2
    ORDER BY system, priority, name
    LIMIT 100;
  " | awk -F',' '{printf "   - %s | %s | %s | %s | %s\n", $1, $2, $3, $4, $5}'
  echo

  echo "6) ملاحظات التعلّم (رؤية من قاعدة البيانات):"
  echo "   - هذا التقرير يعتمد على قاعدة hf_learning.db المبنية من scripts_index.csv."
  echo "   - كل سكربت يعتبر \"عامل\" أو \"مدير\" داخل النظام (hyper / smartfriend / ffactory / generic)."
  echo "   - يمكن ربط هذه المعلومات لاحقًا مع جدول actors (المدراء/العمال) بدون لمس قواعد البيانات الحالية."
  echo "   - first_seen_at / last_seen_at في جدول scripts تمثّل ذاكرة تطوّر السكربتات مع الزمن."
  echo

  echo "=================================================="
  echo "✅ LEARNING DB REPORT مكتمل – التقرير: $OUT"
  echo "=================================================="
} | tee "$OUT"
