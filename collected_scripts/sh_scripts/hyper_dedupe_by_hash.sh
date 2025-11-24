#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
WORK_DIR="$ROOT/tmp_dedupe"

mkdir -p "$WORK_DIR"

LIST_FILE="$WORK_DIR/all_files_$(date +%Y%m%d_%H%M%S).txt"

echo "📂 ROOT: $ROOT"
echo "📁 WORK_DIR: $WORK_DIR"
echo "📄 FILE_LIST: $LIST_FILE"
echo "🔎 جمع قائمة الملفات (بدون .git)..."

# بناء قائمة الملفات (مطلقة)
find "$ROOT" \
  -xdev \
  -type f \
  ! -path "$ROOT/.git/*" \
  > "$LIST_FILE"

TOTAL=$(wc -l < "$LIST_FILE" || echo 0)
echo "🔢 عدد الملفات المرشحة للفحص: $TOTAL"

if [ "$TOTAL" -eq 0 ]; then
  echo "لا يوجد ملفات، خروج."
  exit 0
fi

echo "🚀 تشغيل dedupe بالهاش (6 أنوية + شريط تقدم)..."
python3 "$ROOT/tools/hyper_dedupe_by_hash.py" "$ROOT" "$LIST_FILE"

echo "✅ انتهت عملية إزالة التكرار بالهاش."
