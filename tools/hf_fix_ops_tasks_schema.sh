#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB="$ROOT/db/meta/hf_ops_meta.db"

cd "$ROOT"

if [ ! -f "$DB" ]; then
  echo "❌ لم يتم العثور على قاعدة البيانات: $DB"
  exit 1
fi

echo "== HyperFFactory – Fix hf_ops_meta.tasks schema & indexes =="
echo "DB : $DB"

# 1) التأكد من وجود جدول tasks (إن لم يوجد يتم إنشاؤه بهيكل كامل)
if ! sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';" | grep -qx 'tasks'; then
  echo "⚠️ جدول tasks غير موجود – سيتم إنشاؤه بالهيكل الكامل."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS tasks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT,
  scope      TEXT,
  stage      TEXT,
  category   TEXT,
  code       TEXT,
  title      TEXT,
  task       TEXT,
  status     TEXT,
  owner      TEXT,
  priority   INTEGER,
  last_note  TEXT,
  plan_ref   TEXT,
  created_at TEXT,
  updated_at TEXT
);
SQL
  echo "✅ تم إنشاء جدول tasks بهيكل كامل."
fi

# 2) قراءة أسماء الأعمدة الحالية
cols="$(sqlite3 "$DB" "PRAGMA table_info(tasks);" | awk -F'|' '{print $2}')"
echo "Current columns:"
printf '  - %s\n' $cols

need_add() {
  local name="$1"
  if printf '%s\n' "$cols" | grep -qx "$name"; then
    return 1  # موجود
  else
    return 0  # ناقص
  fi
}

add_text_column() {
  local name="$1"
  echo "➕ إضافة العمود $name..."
  sqlite3 "$DB" "ALTER TABLE tasks ADD COLUMN $name TEXT;"
}

# 3) الأعمدة المطلوبة لدعم HF_EXEC_PLAN + hf_sync_plan_to_tasks.py
for col in actor scope stage category code title task status owner last_note plan_ref created_at updated_at; do
  if need_add "$col"; then
    add_text_column "$col"
  else
    echo "✅ العمود $col موجود."
  fi
done

# priority كـ INTEGER
if need_add "priority"; then
  echo "➕ إضافة العمود priority (INTEGER)..."
  sqlite3 "$DB" "ALTER TABLE tasks ADD COLUMN priority INTEGER;"
else
  echo "✅ العمود priority موجود."
fi

echo
echo "== schema بعد التعديل =="
sqlite3 "$DB" "PRAGMA table_info(tasks);" | awk -F'|' '{printf "%s|%s|%s\n",$1,$2,$3}'

# 4) ضمان وجود قيد UNIQUE على plan_ref لدعم جملة ON CONFLICT(plan_ref)
echo
echo "== indexes على جدول tasks =="
sqlite3 "$DB" "PRAGMA index_list(tasks);"

echo
echo "🔧 إنشاء فهرس UNIQUE على plan_ref (إن لم يكن موجودًا)..."
sqlite3 "$DB" "CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_plan_ref_unique ON tasks(plan_ref);"

echo
echo "✅ hf_ops_meta.tasks جاهز للاستخدام مع hf_sync_plan_to_tasks.py (بما في ذلك ON CONFLICT(plan_ref))"
