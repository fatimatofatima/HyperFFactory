#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
TARGET="$ROOT/all_legacy_dbs"
WORK_DIR="$ROOT/tmp_collect_dbs"

mkdir -p "$WORK_DIR"
mkdir -p "$TARGET"

LIST_FILE="$WORK_DIR/db_files_$(date +%Y%m%d_%H%M%S).txt"

echo "📂 ROOT: $ROOT"
echo "🎯 TARGET: $TARGET"
echo "📄 DB LIST: $LIST_FILE"
echo "🔎 جمع كل ملفات قواعد البيانات داخل HyperFFactory..."

# نعتبر الامتدادات الشائعة لقواعد البيانات
find "$ROOT" \
  -xdev \
  -type f \
  \( -iname '*.db' -o -iname '*.sqlite' -o -iname '*.sqlite3' -o -iname '*.db3' \) \
  ! -path "$TARGET/*" \
  > "$LIST_FILE"

TOTAL=$(wc -l < "$LIST_FILE" || echo 0)
echo "🔢 عدد ملفات DB المرصودة: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  echo "لا يوجد DBs لتجميعها، خروج."
  exit 0
fi

echo "🚀 تشغيل عملية التجميع (6 أنوية + شريط تقدم)..."
python3 "$ROOT/tools/hyper_collect_dbs.py" "$ROOT" "$TARGET" "$LIST_FILE"

echo "✅ انتهت عملية تجميع قواعد البيانات."
