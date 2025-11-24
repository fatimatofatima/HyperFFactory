#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TSV_FILE="$(ls -1 db_inventory_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${TSV_FILE}" ]]; then
  echo "❌ لا يوجد أي ملف db_inventory_*.tsv في $ROOT"
  exit 1
fi

META_DB="$ROOT/meta/hyper_meta.db"
LABEL="scan_$(date +%Y%m%d_%H%M%S)"

echo "📄 استخدام ملف TSV: $TSV_FILE"
echo "🗄️ إنشاء/تحديث قاعدة الميتا: $META_DB"
echo "🏷️ Label: $LABEL"
echo "🚀 بدء الاستيراد..."

python3 "$ROOT/tools/hyper_meta_import_dbs.py" "$TSV_FILE" "$META_DB" "$LABEL"

echo "✅ تم تحديث meta/hyper_meta.db بنجاح"
