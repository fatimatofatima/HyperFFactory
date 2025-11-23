#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
DB_PATH="$ROOT/db/meta/hf_actors.db"

if [[ ! -f "$DB_PATH" ]]; then
  echo "❌ قاعدة بيانات hf_actors.db غير موجودة: $DB_PATH"
  exit 1
fi

echo "=================================================="
echo "🧱 Fix سكيمة hf_actors في: $DB_PATH"
echo "=================================================="

TABLE="$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('hf_actors','actors') LIMIT 1;")"

if [[ -z "$TABLE" ]]; then
  echo "❌ لا يوجد جدول hf_actors/actors داخل hf_actors.db"
  sqlite3 "$DB_PATH" "SELECT name, type FROM sqlite_master WHERE type='table';"
  exit 1
fi

echo "🎯 الجدول المستهدف: $TABLE"

ensure_col() {
  local table="$1"
  local col="$2"
  local type="$3"

  local exists
  exists="$(sqlite3 "$DB_PATH" "PRAGMA table_info('$table');" | awk -F'|' -v c="$col" '$2==c{print 1}')"

  if [[ -z "$exists" ]]; then
    echo "➕ إضافة العمود $col ($type)"
    sqlite3 "$DB_PATH" "ALTER TABLE \"$table\" ADD COLUMN \"$col\" $type;"
  else
    echo "✅ العمود $col موجود بالفعل"
  fi
}

ensure_col "$TABLE" "source_file" "TEXT"
ensure_col "$TABLE" "source_line" "INTEGER"
ensure_col "$TABLE" "meta_json" "TEXT"

echo
echo "📋 PRAGMA table_info بعد التعديل:"
sqlite3 "$DB_PATH" "PRAGMA table_info('$TABLE');"
