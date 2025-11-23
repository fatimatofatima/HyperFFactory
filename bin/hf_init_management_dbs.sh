#!/usr/bin/env bash
# HyperFFactory - Init Management DBs
# إنشاء جداول: Tasks / Quality / Experience / Errors / Progress
# داخل db/meta/hf_ops_meta.db فقط

set -euo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
DB="$DB_DIR/hf_ops_meta.db"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_init_management_dbs_${TS}.log"

mkdir -p "$DB_DIR" "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HF INIT MANAGEMENT DBS START"
log "DB = $DB"
log "=================================================="

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "sqlite3 غير مثبت – يرجى تثبيته ثم إعادة التشغيل."
  exit 1
fi

log "إنشاء/تحديث الجداول داخل hf_ops_meta.db"

sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  scope TEXT,
  status TEXT,
  priority INTEGER,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS quality_checks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  check_name TEXT,
  result TEXT,
  score INTEGER,
  details TEXT,
  ts TEXT
);

CREATE TABLE IF NOT EXISTS experiences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT UNIQUE,
  runs_total INTEGER DEFAULT 0,
  runs_success INTEGER DEFAULT 0,
  runs_failed INTEGER DEFAULT 0,
  success_rate REAL DEFAULT 0.0,
  experience_level TEXT
);

CREATE TABLE IF NOT EXISTS incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  error_type TEXT,
  error_message TEXT,
  severity TEXT,
  ts TEXT,
  context TEXT
);

CREATE TABLE IF NOT EXISTS progress_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  script_name TEXT,
  action TEXT,
  path TEXT,
  status TEXT,
  details TEXT,
  ts TEXT
);
SQL

log "تم إنشاء/تحديث جداول management."

# إدخال سجلات INIT رمزية للتأكد من العمل
sqlite3 "$DB" <<SQL
INSERT INTO progress_log (script_name, action, path, status, details, ts)
VALUES ('hf_init_management_dbs.sh', 'INIT', '$DB', 'SUCCESS', 'Initialize management tables', datetime('now'));

INSERT OR IGNORE INTO experiences (actor, runs_total, runs_success, runs_failed, success_rate, experience_level)
VALUES ('hyperfactory_core', 0, 0, 0, 0.0, 'NOVICE');
SQL

# تلخيص عدد السجلات لكل جدول
log "تلخيص الجداول:"
sqlite3 "$DB" <<'SQL' | tee -a "$LOG"
.headers on
.mode column

SELECT 'tasks' AS table_name, COUNT(*) AS count FROM tasks;
SELECT 'quality_checks' AS table_name, COUNT(*) AS count FROM quality_checks;
SELECT 'experiences' AS table_name, COUNT(*) AS count FROM experiences;
SELECT 'incidents' AS table_name, COUNT(*) AS count FROM incidents;
SELECT 'progress_log' AS table_name, COUNT(*) AS count FROM progress_log;
SQL

log "=================================================="
log "HF INIT MANAGEMENT DBS DONE"
log "LOG = $LOG"
log "=================================================="
