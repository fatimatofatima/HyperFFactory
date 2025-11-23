#!/usr/bin/env bash
# HyperFFactory - Tasks DB Init
# إنشاء/تحديث قاعدة بيانات المهام: db/meta/hf_tasks.db

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_tasks.db"

mkdir -p "$META_DIR"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

echo "=================================================="
echo "🧱 HyperFFactory – Tasks DB Init"
echo "📍 Root : $ROOT_DIR"
echo "📄 DB   : $DB"
echo "=================================================="

sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS tasks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  actor       TEXT NOT NULL,           -- من ينفّذ (hyper_brain_controller / sf-core / ffactory_controller...)
  scope       TEXT NOT NULL,           -- نطاق المهمة (smartfriend/ffactory/hyper/infra/backup/...)
  title       TEXT NOT NULL,           -- عنوان قصير للمهمة
  status      TEXT NOT NULL DEFAULT 'PLANNED'
                 CHECK(status IN ('PLANNED','RUNNING','DONE','FAILED','SKIPPED')),
  priority    INTEGER NOT NULL DEFAULT 5,  -- 1 = أعلى أولوية
  tags        TEXT,                    -- نص حر (csv أو json خفيف)
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_status      ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_actor       ON tasks(actor);
CREATE INDEX IF NOT EXISTS idx_tasks_scope       ON tasks(scope);
CREATE INDEX IF NOT EXISTS idx_tasks_priority    ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at  ON tasks(created_at);
SQL

echo "✅ تم إنشاء/تحديث قاعدة بيانات المهام: $DB"

# تسجيل التقدّم إن وُجد hf_progress_log.sh
if [[ -x "$ROOT_DIR/bin/hf_progress_log.sh" ]]; then
  "$ROOT_DIR/bin/hf_progress_log.sh" "hf_tasks_init" "DONE" "تهيئة قاعدة بيانات المهام hf_tasks.db"
fi

echo "=================================================="
echo "✅ hf_tasks_init.sh انتهى بنجاح."
echo "=================================================="
