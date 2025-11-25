#!/usr/bin/env bash
# HyperFFactory – Registry Builder (READ-ONLY SOURCES)
# - يبني db/meta/hf_registry.db من:
#   * ملفات db/meta/*.db
#   * سكربتات tools/hf_*.sh

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
TOOLS_DIR="$ROOT/tools"
DB_REG="$META_DIR/hf_registry.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت."
  exit 1
fi

mkdir -p "$META_DIR"

echo "=================================================="
echo " HyperFFactory – Registry Build"
echo " ROOT : $ROOT"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo " OUT  : $DB_REG"
echo "=================================================="

# إعادة إنشاء قاعدة registry فقط
rm -f "$DB_REG"

sqlite3 "$DB_REG" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE systems_registry (
  system_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL,
  name        TEXT NOT NULL,
  category    TEXT,
  status      TEXT
);

CREATE TABLE db_registry (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  file_name           TEXT NOT NULL,
  system_code         TEXT NOT NULL,
  path                TEXT NOT NULL,
  size_bytes          INTEGER,
  has_tasks_table     INTEGER DEFAULT 0,
  has_workers_table   INTEGER DEFAULT 0,
  has_patterns_table  INTEGER DEFAULT 0,
  has_incidents_table INTEGER DEFAULT 0,
  note                TEXT
);

CREATE TABLE scripts_registry (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  system_code   TEXT NOT NULL,
  role          TEXT,
  kind          TEXT,
  path          TEXT NOT NULL,
  is_executable INTEGER DEFAULT 0
);
SQL

# تسجيل نظام HyperFFactory الأساسي
sqlite3 "$DB_REG" <<'SQL'
INSERT INTO systems_registry (code, name, category, status)
VALUES ('hyper_ffactory', 'HyperFFactory Core', 'orchestrator', 'ACTIVE');
SQL

# فحص كل db/meta/*.db وتسجيلها في db_registry
for db in "$META_DIR"/*.db; do
  [ -e "$db" ] || continue

  file_name="$(basename "$db")"
  size_bytes="$(stat -c '%s' "$db" 2>/dev/null || echo 0)"
  system_code="hyper_ffactory"

  has_tasks=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tasks';" 2>/dev/null || echo 0)
  has_workers=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='workers';" 2>/dev/null || echo 0)
  has_patterns=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='patterns';" 2>/dev/null || echo 0)
  has_incidents=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='incidents';" 2>/dev/null || echo 0)

  esc_file_name="$(printf "%s" "$file_name" | sed "s/'/''/g")"
  esc_path="$(printf "%s" "$db" | sed "s/'/''/g")"

  sqlite3 "$DB_REG" <<SQL
INSERT INTO db_registry (
  file_name, system_code, path, size_bytes,
  has_tasks_table, has_workers_table, has_patterns_table, has_incidents_table, note
) VALUES (
  '$esc_file_name',
  '$system_code',
  '$esc_path',
  $size_bytes,
  $has_tasks,
  $has_workers,
  $has_patterns,
  $has_incidents,
  ''
);
SQL
done

# فحص سكربتات tools/hf_*.sh وتسجيلها في scripts_registry
if [ -d "$TOOLS_DIR" ]; then
  for f in "$TOOLS_DIR"/hf_*.sh; do
    [ -e "$f" ] || continue

    name="$(basename "$f")"
    path="$f"
    system_code="hyper_ffactory"
    is_exec=0
    [ -x "$f" ] && is_exec=1

    role=""
    kind="utility"

    case "$name" in
      hf_*stage9*|hf_*stage10*)
        role="pipeline"
        ;;
      hf_db_*|*db_manager*|*db_audit*)
        role="db"
        ;;
      *tasks*|*scheduler*|*cron*)
        role="tasks"
        ;;
      *dashboard*|*kpi*|*status*|*quality*)
        role="governance"
        ;;
      *patterns*|*learning*)
        role="patterns"
        ;;
    esac

    esc_name="$(printf "%s" "$name" | sed "s/'/''/g")"
    esc_role="$(printf "%s" "$role" | sed "s/'/''/g")"
    esc_path="$(printf "%s" "$path" | sed "s/'/''/g")"

    sqlite3 "$DB_REG" <<SQL
INSERT INTO scripts_registry (name, system_code, role, kind, path, is_executable)
VALUES (
  '$esc_name',
  '$system_code',
  '$esc_role',
  '$kind',
  '$esc_path',
  $is_exec
);
SQL
  done
fi

echo
echo "📊 ملخص registry:"
sqlite3 "$DB_REG" "SELECT COUNT(*) AS systems FROM systems_registry;" 2>/dev/null || true
sqlite3 "$DB_REG" "SELECT COUNT(*) AS db_files FROM db_registry;" 2>/dev/null || true
sqlite3 "$DB_REG" "SELECT COUNT(*) AS scripts FROM scripts_registry;" 2>/dev/null || true

echo
echo "✅ تم بناء hf_registry.db بنجاح (READ-ONLY SOURCE SCAN)."
