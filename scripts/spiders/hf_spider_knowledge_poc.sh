#!/usr/bin/env bash
# HyperFFactory – Spider PoC للمعرفة
# يأخذ كل ملف *.txt من data/knowledge_raw ويضيفه إلى knowledge_items.

set -euo pipefail

ROOT="/root/HyperFFactory"
KNOW_RAW="$ROOT/data/knowledge_raw"
KNOW_DB="$ROOT/db/meta/hf_knowledge.db"

cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير متوفر في PATH."
  exit 1
fi

echo "🕷 تشغيل Spider PoC – مصدر البيانات: $KNOW_RAW"

shopt -s nullglob
files=("$KNOW_RAW"/*.txt)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️ لا يوجد ملفات *.txt في $KNOW_RAW – لا يوجد شيء لإدخاله."
  exit 0
fi

for f in "${files[@]}"; do
  base="$(basename "$f")"
  key="${base%.*}"
  # قراءة المحتوى مع استبدال ' بـ '' لتفادي كسر SQL
  content_raw="$(cat "$f")"
  content_escaped="${content_raw//\'/''}"

  sqlite3 "$KNOW_DB" <<SQL
INSERT INTO knowledge_items (source_system, kind, item_key, content, tags, meta_json)
VALUES (
  'local_spider',
  'text_file',
  '$key',
  '$content_escaped',
  NULL,
  NULL
);
SQL

  echo "✅ تم إدخال ملف: $base (key=$key)"
done

echo "✅ Spider PoC انتهى بنجاح."
