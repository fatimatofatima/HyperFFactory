#!/usr/bin/env bash
# HyperFFactory – Meta Fix for Four Systems
# يضبط سكيمات:
#  - hf_tasks.db      → جدول hf_tasks (الريجستري)
#  - hf_quality.db    → جدول quality_checks
#  - hf_errors.db     → جدول errors
#  - hf_actors.db     → جداول الخبرة (hf_actor_stats جاهز، hf_training_sessions جاهز)
# ويعمل Smoke Test على:
#  - المهام
#  - الجودة
#  - الأخطاء

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

META_DIR="$ROOT/db/meta"
HF_TASKS_DB="$META_DIR/hf_tasks.db"
HF_QUALITY_DB="$META_DIR/hf_quality.db"
HF_ERRORS_DB="$META_DIR/hf_errors.db"
HF_ACTORS_DB="$META_DIR/hf_actors.db"
HF_CHANGES_DB="$META_DIR/hf_changes.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

echo "====================================================="
echo " HyperFFactory – Meta Fix Four Systems"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " TIME : $(ts)"
echo "====================================================="

mkdir -p "$META_DIR"

has_table() {
  local db="$1" table="$2"
  sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" 2>/dev/null \
    | grep -qx "$table"
}

ensure_column() {
  local db="$1" table="$2" col="$3" ddl="$4"
  if sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" 2>/dev/null | grep -qx "$table"; then
    local exists
    exists="$(sqlite3 "$db" "PRAGMA table_info($table);" 2>/dev/null | awk -F'|' '{print $2}' | grep -x "$col" || true)"
    if [ -z "$exists" ]; then
      echo "  [DB] Adding missing column $table.$col ..."
      sqlite3 "$db" "$ddl"
    fi
  fi
}

# ------------------------------------------------------
# 1) ضمان سكيمة hf_tasks (الريجستري الرسمي)
# ------------------------------------------------------
echo
echo "[1] Ensuring hf_tasks schema in $HF_TASKS_DB ..."

if [ -x bin/hf_tasks_ensure_schema.sh ]; then
  bin/hf_tasks_ensure_schema.sh
else
  echo "  [WARN] bin/hf_tasks_ensure_schema.sh غير موجود – إنشاء الجدول يدويًا."
  sqlite3 "$HF_TASKS_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS hf_tasks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT NOT NULL,
  scope      TEXT NOT NULL,
  status     TEXT NOT NULL,
  priority   INTEGER NOT NULL DEFAULT 0,
  title      TEXT,
  tags       TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_hf_tasks_actor_scope
  ON hf_tasks(actor, scope);
CREATE INDEX IF NOT EXISTS idx_hf_tasks_status
  ON hf_tasks(status);
SQL
fi

echo "  [OK] hf_tasks schema ensured."

# ------------------------------------------------------
# 2) ضمان سكيمة الجودة (quality_checks) بما يطابق تقريرك
#    schema من hf_quality_report:
#    id, actor, check_name, result, score, details, tags, ts, scope, check_key, target, created_at
# ------------------------------------------------------
echo
echo "[2] Ensuring quality_checks schema in $HF_QUALITY_DB ..."

mkdir -p "$(dirname "$HF_QUALITY_DB")"

if ! has_table "$HF_QUALITY_DB" "quality_checks"; then
  echo "  [DB] Creating table quality_checks ..."
  sqlite3 "$HF_QUALITY_DB" <<'SQL'
CREATE TABLE quality_checks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT    NOT NULL,
  check_name TEXT    NOT NULL,
  result     TEXT    NOT NULL,
  score      INTEGER NOT NULL,
  details    TEXT,
  tags       TEXT,
  ts         TEXT    NOT NULL,
  scope      TEXT,
  check_key  TEXT,
  target     TEXT,
  created_at TEXT
);
SQL
else
  echo "  [DB] Table quality_checks exists – checking columns ..."
  ensure_column "$HF_QUALITY_DB" "quality_checks" "actor"      "ALTER TABLE quality_checks ADD COLUMN actor TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "check_name" "ALTER TABLE quality_checks ADD COLUMN check_name TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "result"     "ALTER TABLE quality_checks ADD COLUMN result TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "score"      "ALTER TABLE quality_checks ADD COLUMN score INTEGER;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "details"    "ALTER TABLE quality_checks ADD COLUMN details TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "tags"       "ALTER TABLE quality_checks ADD COLUMN tags TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "ts"         "ALTER TABLE quality_checks ADD COLUMN ts TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "scope"      "ALTER TABLE quality_checks ADD COLUMN scope TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "check_key"  "ALTER TABLE quality_checks ADD COLUMN check_key TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "target"     "ALTER TABLE quality_checks ADD COLUMN target TEXT;"
  ensure_column "$HF_QUALITY_DB" "quality_checks" "created_at" "ALTER TABLE quality_checks ADD COLUMN created_at TEXT;"
fi

echo "  [OK] quality_checks schema ensured."

# ------------------------------------------------------
# 3) ضمان سكيمة الأخطاء (errors) بما يتماشى مع incidents_report
#    schema من hf_incidents_report:
#    id, actor, error_type, error_message, severity, context, tags, ts,
#    state DEFAULT 'OPEN', resolved_at, task_id, scope
# ------------------------------------------------------
echo
echo "[3] Ensuring errors schema in $HF_ERRORS_DB ..."

mkdir -p "$(dirname "$HF_ERRORS_DB")"

if ! has_table "$HF_ERRORS_DB" "errors"; then
  echo "  [DB] Creating table errors ..."
  sqlite3 "$HF_ERRORS_DB" <<'SQL'
CREATE TABLE errors (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  actor          TEXT    NOT NULL,
  error_type     TEXT    NOT NULL,
  error_message  TEXT    NOT NULL,
  severity       TEXT    NOT NULL,
  context        TEXT,
  tags           TEXT,
  ts             TEXT    NOT NULL,
  state          TEXT    DEFAULT 'OPEN',
  resolved_at    TEXT,
  task_id        INTEGER,
  scope          TEXT
);
SQL
else
  echo "  [DB] Table errors exists – checking columns ..."
  ensure_column "$HF_ERRORS_DB" "errors" "actor"         "ALTER TABLE errors ADD COLUMN actor TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "error_type"    "ALTER TABLE errors ADD COLUMN error_type TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "error_message" "ALTER TABLE errors ADD COLUMN error_message TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "severity"      "ALTER TABLE errors ADD COLUMN severity TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "context"       "ALTER TABLE errors ADD COLUMN context TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "tags"          "ALTER TABLE errors ADD COLUMN tags TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "ts"            "ALTER TABLE errors ADD COLUMN ts TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "state"         "ALTER TABLE errors ADD COLUMN state TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "resolved_at"   "ALTER TABLE errors ADD COLUMN resolved_at TEXT;"
  ensure_column "$HF_ERRORS_DB" "errors" "task_id"       "ALTER TABLE errors ADD COLUMN task_id INTEGER;"
  ensure_column "$HF_ERRORS_DB" "errors" "scope"         "ALTER TABLE errors ADD COLUMN scope TEXT;"
fi

echo "  [OK] errors schema ensured."

# ------------------------------------------------------
# 4) طبقة الخبرة – ضمان hf_training_sessions
# ------------------------------------------------------
echo
echo "[4] Ensuring experience tables in $HF_ACTORS_DB ..."

mkdir -p "$(dirname "$HF_ACTORS_DB")"

sqlite3 "$HF_ACTORS_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS hf_training_sessions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  actor        TEXT NOT NULL,
  session_type TEXT,
  description  TEXT,
  started_at   TEXT NOT NULL,
  finished_at  TEXT,
  outcome      TEXT,
  notes        TEXT
);
SQL

echo "  [OK] hf_training_sessions ensured."
echo "  [INFO] hf_actor_stats left as-is (managed by existing policies)."

# ------------------------------------------------------
# 5) Smoke Test – Task + Quality + Error
# ------------------------------------------------------
echo
echo "[5] Smoke Test – creating test task + quality check + error incident ..."

TEST_TASK_ID=""

if [ -x bin/hf_tasks_admin.sh ]; then
  echo "  [TEST] Creating test task via hf_tasks_admin.sh ..."
  out="$(bash bin/hf_tasks_admin.sh create \
          "hyper_guard" \
          "Four-systems meta test" \
          "meta:four-systems" \
          10 \
          "[meta]")" || true
  echo "$out"
  TEST_TASK_ID="$(echo "$out" | awk '/ID[[:space:]]*:/ {print $3}' | tail -n1 || true)"
  if [[ "$TEST_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "  [TEST] Marking task $TEST_TASK_ID RUNNING → DONE ..."
    if [ -x tools/hf_tasks_mark.sh ]; then
      bash tools/hf_tasks_mark.sh "$TEST_TASK_ID" RUNNING || true
    fi
    bash bin/hf_tasks_admin.sh set-status "$TEST_TASK_ID" DONE "four-systems-smoke" || true
  else
    echo "  [WARN] لم أستطع استخراج TEST_TASK_ID من مخرجات create (لن أوقف السكربت)."
  fi
else
  echo "  [WARN] bin/hf_tasks_admin.sh غير موجود/غير قابل للتنفيذ – تخطي اختبار المهام."
fi

echo
echo "  [TEST] Inserting sample row into quality_checks ..."
# ملاحظة: نلتزم بالسكيمة الفعلية:
# actor, check_name, result, score, details, tags, ts, scope, check_key, target, created_at
sqlite3 "$HF_QUALITY_DB" <<'SQL'
INSERT INTO quality_checks (
  actor,
  check_name,
  result,
  score,
  details,
  tags,
  ts,
  scope,
  check_key,
  target,
  created_at
) VALUES (
  'meta_tester',
  'four_systems_smoke',
  'OK',
  100,
  'bootstrap quality check',
  '[meta,smoke]',
  datetime('now'),
  'meta:four-systems',
  'four_systems_smoke',
  'hf/meta',
  datetime('now')
);
SQL

echo "  [TEST] Inserting sample row into errors ..."
sqlite3 "$HF_ERRORS_DB" <<'SQL'
INSERT INTO errors (
  actor,
  error_type,
  error_message,
  severity,
  context,
  tags,
  ts,
  state,
  resolved_at,
  task_id,
  scope
) VALUES (
  'meta_tester',
  'INTEGRATION_TEST',
  'meta four-systems smoke incident',
  'LOW',
  'bootstrap smoke test',
  '[meta,smoke]',
  datetime('now'),
  'RESOLVED',
  datetime('now'),
  NULL,
  'meta:four-systems'
);
SQL

# ------------------------------------------------------
# 6) تشغيل تقارير الجودة / الحوادث لو موجودة
# ------------------------------------------------------
echo
echo "[6] Running reports if available ..."

if [ -x bin/hf_quality_report.sh ]; then
  echo "----- hf_quality_report.sh -----"
  bin/hf_quality_report.sh || echo "  [WARN] hf_quality_report.sh returned non-zero exit code."
else
  echo "  [INFO] bin/hf_quality_report.sh غير موجود/غير قابل للتنفيذ – تخطي."
fi

echo

if [ -x bin/hf_incidents_report.sh ]; then
  echo "----- hf_incidents_report.sh -----"
  bin/hf_incidents_report.sh || echo "  [WARN] hf_incidents_report.sh returned non-zero exit code."
else
  echo "  [INFO] bin/hf_incidents_report.sh غير موجود/غير قابل للتنفيذ – تخطي."
fi

echo
echo "====================================================="
echo " Meta Fix Four Systems – DONE"
echo "====================================================="
