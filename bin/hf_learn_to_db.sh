#!/usr/bin/env bash
# HyperFFactory - Learning Layer: Load scripts_index.csv into SQLite "hf_learning.db"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
LEARN_DIR="$ROOT_DIR/learning"
META_DIR="$ROOT_DIR/db/meta"

CSV="$LEARN_DIR/scripts_index.csv"
DB="$META_DIR/hf_learning.db"

mkdir -p "$META_DIR"

if [[ ! -f "$CSV" ]]; then
  echo "❌ ملف الفهرس غير موجود: $CSV" >&2
  echo "   شغّل أولاً: bin/hf_learn_index.sh" >&2
  exit 1
fi

echo "🧠 تحميل فهرس السكربتات إلى قاعدة التعلّم: $DB"

# إنشاء الجدول إن لم يكن موجودًا
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS scripts (
  path          TEXT PRIMARY KEY,
  csv_id        INTEGER,
  role          TEXT,
  priority      INTEGER,
  system        TEXT,
  category      TEXT,
  name          TEXT,
  first_seen_at TEXT,
  last_seen_at  TEXT
);

CREATE INDEX IF NOT EXISTS idx_scripts_system
  ON scripts(system);

CREATE INDEX IF NOT EXISTS idx_scripts_role
  ON scripts(role);

CREATE INDEX IF NOT EXISTS idx_scripts_category
  ON scripts(category);
SQL

# قراءة CSV وتعبئة الجدول
tail -n +2 "$CSV" | while IFS=',' read -r csv_id role priority system category name path; do
  # تنظيف القيم من المسافات الزائدة
  csv_id="${csv_id//[$'\r\n']/}"
  role="${role//[$'\r\n']/}"
  priority="${priority//[$'\r\n']/}"
  system="${system//[$'\r\n']/}"
  category="${category//[$'\r\n']/}"
  name="${name//[$'\r\n']/}"
  path="${path//[$'\r\n']/}"

  # هروب علامات '
  role_sql="${role//\'/\'\'}"
  system_sql="${system//\'/\'\'}"
  category_sql="${category//\'/\'\'}"
  name_sql="${name//\'/\'\'}"
  path_sql="${path//\'/\'\'}"

  # priority رقمية؛ لو فاضية نعين 5
  if [[ -z "${priority:-}" ]]; then
    priority="5"
  fi

  NOW="$(date '+%Y-%m-%d %H:%M:%S')"

  sqlite3 "$DB" "
    INSERT INTO scripts (path, csv_id, role, priority, system, category, name, first_seen_at, last_seen_at)
    VALUES ('$path_sql', $csv_id, '$role_sql', $priority, '$system_sql', '$category_sql', '$name_sql', '$NOW', '$NOW')
    ON CONFLICT(path) DO UPDATE SET
      csv_id        = excluded.csv_id,
      role          = excluded.role,
      priority      = excluded.priority,
      system        = excluded.system,
      category      = excluded.category,
      name          = excluded.name,
      last_seen_at  = excluded.last_seen_at;
  "
done

echo "✅ تم تحميل الفهرس إلى قاعدة التعلّم بنجاح: $DB"
