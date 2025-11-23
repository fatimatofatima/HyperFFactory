#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
DB_PATH="$ROOT/db/meta/hf_actors.db"

if [ ! -f "$DB_PATH" ]; then
  echo "❌ قاعدة البيانات غير موجودة: $DB_PATH"
  echo "➡️ شغّل أولاً: bin/hf_init_actors_db.sh ثم bin/hf_scan_actors.sh"
  exit 1
fi

echo "=================================================="
echo "📊 HyperFFactory – تقرير المدراء والعمال"
echo "DB : $DB_PATH"
echo "=================================================="

echo
echo "🔹 توزيع حسب النوع (MANAGER / WORKER / UNKNOWN)"
sqlite3 "$DB_PATH" "SELECT role_type, COUNT(*) AS cnt FROM hf_actors GROUP BY role_type ORDER BY cnt DESC;"

echo
echo "🔹 أمثلة من المدراء (MANAGER):"
sqlite3 -header -column "$DB_PATH" "
  SELECT id, name, source_root,
         substr(source_path, 1, 50) AS path
  FROM hf_actors
  WHERE role_type = 'MANAGER'
  ORDER BY id
  LIMIT 20;
"

echo
echo "🔹 أمثلة من العمال (WORKER):"
sqlite3 -header -column "$DB_PATH" "
  SELECT id, name, source_root,
         substr(source_path, 1, 50) AS path
  FROM hf_actors
  WHERE role_type = 'WORKER'
  ORDER BY id
  LIMIT 20;
"

echo
echo "🔹 أمثلة من العلامات (Tags) المرتبطة:"
sqlite3 -header -column "$DB_PATH" "
  SELECT a.id AS actor_id,
         a.name,
         t.key,
         t.value
  FROM hf_actor_tags t
  JOIN hf_actors a ON a.id = t.actor_id
  ORDER BY a.id, t.key
  LIMIT 40;
"

echo
echo "✅ تقرير المدراء/العمال مكتمل."
