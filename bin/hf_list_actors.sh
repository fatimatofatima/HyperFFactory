#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
DB_PATH="$ROOT/db/meta/hf_actors.db"

if [[ ! -f "$DB_PATH" ]]; then
  echo "❌ قاعدة بيانات hf_actors.db غير موجودة: $DB_PATH"
  echo "ℹ️ شغّل أولاً: bin/hf_fix_actors_schema.sh ثم أي سكربت scan/seed للـ actors."
  exit 1
fi

TABLE="$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('hf_actors','actors') LIMIT 1;")"

if [[ -z "$TABLE" ]]; then
  echo "❌ لا يوجد جدول hf_actors/actors داخل hf_actors.db"
  sqlite3 "$DB_PATH" "SELECT name, type FROM sqlite_master WHERE type='table';"
  exit 1
fi

echo "=================================================="
echo "📊 HyperFFactory – تقرير المدراء والعمال (hf_actors)"
echo "📂 DB   : $DB_PATH"
echo "📋 Table: $TABLE"
echo "⏰ Time : $(date)"
echo "=================================================="
echo

echo "ملخص حسب نوع الدور (role_type):"
sqlite3 -header -column "$DB_PATH" "
  SELECT
    COALESCE(role_type, 'UNKNOWN') AS role_type,
    COUNT(*) AS count
  FROM \"$TABLE\"
  GROUP BY COALESCE(role_type, 'UNKNOWN')
  ORDER BY count DESC, role_type ASC;
"

echo
echo "----------------------------------------------"
echo "📋 القائمة التفصيلية (id, name, role_type, source_file, source_line)"
echo "----------------------------------------------"

sqlite3 -header -column "$DB_PATH" "
  SELECT
    id,
    name,
    COALESCE(role_type, 'UNKNOWN') AS role_type,
    COALESCE(source_file, '')      AS source_file,
    COALESCE(source_line, '')      AS source_line
  FROM \"$TABLE\"
  ORDER BY role_type, name
  LIMIT 200;
"
