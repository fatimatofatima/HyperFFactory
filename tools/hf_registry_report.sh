#!/usr/bin/env bash
# HyperFFactory – Registry & Index Report
# - READ-ONLY على كل db/meta/*.db
# - يكتشف أي جدول اسمه يحتوي على كلمة registry
# - يطبع:
#   * اسم الـ DB
#   * اسم الجدول
#   * عدد السجلات
#   * تعريف الجدول (CREATE TABLE)
#   * الفهارس (indexes) على الجدول

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

ts() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

echo "====================================================="
echo " HyperFFactory – Registry & Index Report"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " TIME : $(ts)"
echo "====================================================="

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت على النظام." >&2
  exit 1
fi

if [ ! -d "$META_DIR" ]; then
  echo "❌ مجلد الميتا غير موجود: $META_DIR" >&2
  exit 1
fi

shopt -s nullglob
DB_LIST=("$META_DIR"/*.db)
shopt -u nullglob

if [ ${#DB_LIST[@]} -eq 0 ]; then
  echo "⚠️ لا توجد ملفات .db داخل $META_DIR"
  exit 0
fi

FOUND_ANY=0

for DB in "${DB_LIST[@]}"; do
  echo
  echo "-----------------------------------------------------"
  echo "📦 قاعدة بيانات: $DB"
  echo "-----------------------------------------------------"

  # نجيب الجداول التي تحتوي على كلمة registry في الاسم
  TABLES=$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%registry%';" || true)

  if [ -z "$TABLES" ]; then
    echo "  ⚠️ لا توجد جداول تحتوي على 'registry' في هذه القاعدة."
    continue
  fi

  FOUND_ANY=1

  while IFS= read -r TBL; do
    [ -z "$TBL" ] && continue

    echo
    echo "  ==============================================="
    echo "  🧾 جدول registry: $TBL"
    echo "  ==============================================="

    # عدد السجلات
    ROWS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM \"$TBL\";" 2>/dev/null || echo "?")
    echo "  • عدد السجلات: $ROWS"

    echo
    echo "  • تعريف الجدول (schema):"
    sqlite3 "$DB" "SELECT sql FROM sqlite_master WHERE type='table' AND name='$TBL';" 2>/dev/null \
      | sed 's/^/    /' || echo "    ⚠️ تعذر قراءة تعريف الجدول"

    echo
    echo "  • الفهارس (indexes):"
    IDX=$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='$TBL';" 2>/dev/null || true)
    if [ -z "$IDX" ]; then
      echo "    ⚠️ لا توجد فهارس معرفة على هذا الجدول."
    else
      while IFS= read -r INAME; do
        [ -z "$INAME" ] && continue
        echo "    - index: $INAME"
        sqlite3 "$DB" "SELECT sql FROM sqlite_master WHERE type='index' AND name='$INAME';" 2>/dev/null \
          | sed 's/^/      /' || echo "      ⚠️ تعذر قراءة تعريف الـ index"
      done <<< "$IDX"
    fi

  done <<< "$TABLES"

done

if [ "$FOUND_ANY" -eq 0 ]; then
  echo
  echo "⚠️ لم يتم العثور على أي جدول اسمه يحتوي على 'registry' داخل db/meta/*.db"
else
  echo
  echo "✅ تقرير الريجستري والفهارس (indexes) اكتمل."
fi
