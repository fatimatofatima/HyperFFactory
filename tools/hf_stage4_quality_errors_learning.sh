#!/usr/bin/env bash
# ============================================
# HF Stage 4 – Quality / Errors / Learning DBs
# ============================================
# الهدف:
#   - إنشاء قواعد meta مستقلة:
#       * hf_quality.db      → نظام الجودة
#       * hf_errors.db       → نظام الأخطاء
#       * hf_learning.db     → نظام التعلّم
#   - تعريف جداول أساسية في كل DB (schema خفيف لكن عملي)
#   - فحص سريع لصحة الـ DBs (integrity_check)
#   - تحديث المهام التالية في hf_tasks.db إلى DONE:
#       * quality_system
#       * errors_system
#       * learning_system
#
# المبدأ:
#   - كل التغييرات داخل /root/HyperFFactory فقط.
#   - لا يوجد أي تعديل على ffactory أو SmartFriend Suite أو smartfrind.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${HYPER_ROOT}/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/hf_stage4_quality_errors_learning_${TS}.log"

META_DIR="${HYPER_ROOT}/db/meta"
mkdir -p "$META_DIR"

QUALITY_DB="${META_DIR}/hf_quality.db"
ERRORS_DB="${META_DIR}/hf_errors.db"
LEARNING_DB="${META_DIR}/hf_learning.db"

TASKS_DB="${META_DIR}/hf_tasks.db"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "====================================================="
echo "HF Stage 4 – Quality / Errors / Learning DBs"
echo "====================================================="
echo "ROOT       : $HYPER_ROOT"
echo "META_DIR   : $META_DIR"
echo "QUALITY_DB : $QUALITY_DB"
echo "ERRORS_DB  : $ERRORS_DB"
echo "LEARNING_DB: $LEARNING_DB"
echo "TASKS_DB   : $TASKS_DB"
echo "TIME       : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

need_sqlite() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "❌ أداة sqlite3 غير موجودة – يرجى تثبيتها ثم إعادة تشغيل Stage 4."
    exit 1
  fi
}

# ------------------------------------------------------
# 1) إنشاء hf_quality.db + الجداول الأساسية
# ------------------------------------------------------
init_quality_db() {
  sep "1) إنشاء / تحديث hf_quality.db (Quality System)"

  need_sqlite

  echo "[i] إنشاء الجداول (IF NOT EXISTS) في: $QUALITY_DB"
  sqlite3 "$QUALITY_DB" "
    PRAGMA journal_mode=WAL;

    CREATE TABLE IF NOT EXISTS quality_metrics (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      metric_code  TEXT NOT NULL UNIQUE,
      name         TEXT NOT NULL,
      description  TEXT,
      target_value REAL,
      unit         TEXT,
      is_active    INTEGER NOT NULL DEFAULT 1,
      created_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS quality_checks (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      check_code     TEXT NOT NULL,
      metric_code    TEXT NOT NULL,
      scope          TEXT NOT NULL, -- hyper, smartfriend, ffactory, lakehouse, ...
      severity       TEXT NOT NULL, -- INFO/WARN/CRITICAL
      schedule_hint  TEXT,          -- e.g. daily/hourly/on-demand
      created_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS quality_runs (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      check_code   TEXT NOT NULL,
      target       TEXT NOT NULL,    -- ما الذي تم فحصه (db/file/service/stack...)
      status       TEXT NOT NULL,    -- OK / WARN / FAIL
      details      TEXT,
      started_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      finished_at  TEXT
    );
  "

  echo
  echo "[i] فحص سلامة hf_quality.db:"
  sqlite3 "$QUALITY_DB" "PRAGMA integrity_check;" || echo "⚠️ مشكلة في integrity_check لـ hf_quality.db"

  echo
  echo "[i] عدد الجداول في hf_quality.db:"
  sqlite3 -header -column "$QUALITY_DB" "SELECT name FROM sqlite_master WHERE type='table';" || true
}

# ------------------------------------------------------
# 2) إنشاء hf_errors.db + الجداول الأساسية
# ------------------------------------------------------
init_errors_db() {
  sep "2) إنشاء / تحديث hf_errors.db (Errors System)"

  need_sqlite

  echo "[i] إنشاء الجداول (IF NOT EXISTS) في: $ERRORS_DB"
  sqlite3 "$ERRORS_DB" "
    PRAGMA journal_mode=WAL;

    CREATE TABLE IF NOT EXISTS error_events (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      source       TEXT NOT NULL,    -- hyper, smartfriend, ffactory, systemd, docker...
      component    TEXT NOT NULL,    -- service/script/db/stack...
      error_code   TEXT,
      severity     TEXT NOT NULL,    -- INFO/WARN/ERROR/CRITICAL
      message      TEXT NOT NULL,
      context      TEXT,             -- JSON أو نص حر
      created_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS error_stats (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      source       TEXT NOT NULL,
      component    TEXT NOT NULL,
      severity     TEXT NOT NULL,
      window_key   TEXT NOT NULL,    -- e.g. 2025-11-25, 2025-11-25T05, ...
      error_count  INTEGER NOT NULL DEFAULT 0,
      last_update  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  "

  echo
  echo "[i] فحص سلامة hf_errors.db:"
  sqlite3 "$ERRORS_DB" "PRAGMA integrity_check;" || echo "⚠️ مشكلة في integrity_check لـ hf_errors.db"

  echo
  echo "[i] عدد الجداول في hf_errors.db:"
  sqlite3 -header -column "$ERRORS_DB" "SELECT name FROM sqlite_master WHERE type='table';" || true
}

# ------------------------------------------------------
# 3) إنشاء hf_learning.db + الجداول الأساسية
# ------------------------------------------------------
init_learning_db() {
  sep "3) إنشاء / تحديث hf_learning.db (Learning System)"

  need_sqlite

  echo "[i] إنشاء الجداول (IF NOT EXISTS) في: $LEARNING_DB"
  sqlite3 "$LEARNING_DB" "
    PRAGMA journal_mode=WAL;

    CREATE TABLE IF NOT EXISTS learning_events (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      source        TEXT NOT NULL,    -- hyper, smartfriend, ffactory, game_engine...
      event_type    TEXT NOT NULL,    -- success, failure, anomaly, pattern, ...
      reference_id  TEXT,             -- task id / round id / job id...
      payload       TEXT,             -- JSON أو نص حر
      created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS lessons_learned (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      lesson_code   TEXT NOT NULL UNIQUE,
      title         TEXT NOT NULL,
      description   TEXT,
      impact_area   TEXT,             -- risk, performance, accuracy, operations...
      confidence    REAL DEFAULT 0.0, -- 0–1
      created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS learning_jobs (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      job_code      TEXT NOT NULL,
      status        TEXT NOT NULL,    -- PLANNED/RUNNING/DONE/FAILED
      scope         TEXT NOT NULL,    -- أي نطاق تعلّم (game, ocr, factory...)
      params        TEXT,             -- JSON
      result        TEXT,
      created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  "

  echo
  echo "[i] فحص سلامة hf_learning.db:"
  sqlite3 "$LEARNING_DB" "PRAGMA integrity_check;" || echo "⚠️ مشكلة في integrity_check لـ hf_learning.db"

  echo
  echo "[i] عدد الجداول في hf_learning.db:"
  sqlite3 -header -column "$LEARNING_DB" "SELECT name FROM sqlite_master WHERE type='table';" || true
}

# ------------------------------------------------------
# 4) تحديث مهام quality/errors/learning في hf_tasks.db
# ------------------------------------------------------
update_tasks_status() {
  sep "4) تحديث مهام quality_system / errors_system / learning_system → DONE في hf_tasks.db"

  if [[ ! -f "$TASKS_DB" ]]; then
    echo "⚠️ لم يتم العثور على hf_tasks.db: $TASKS_DB"
    echo "   لن يتم تعديل حالة المهام."
    return
  fi

  need_sqlite

  echo "[A] حالة المهام قبل التحديث:"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT id,actor,scope,status,priority,title,created_at,updated_at
    FROM tasks
    ORDER BY id;
  " || echo "⚠️ خطأ أثناء قراءة المهام قبل التحديث."

  echo
  echo "[B] تعيين المهام إلى DONE (quality_system, errors_system, learning_system)..."
  sqlite3 "$TASKS_DB" "
    UPDATE tasks
    SET status='DONE',
        updated_at=CURRENT_TIMESTAMP
    WHERE scope IN ('quality_system','errors_system','learning_system')
      AND status <> 'DONE';
  " || echo "⚠️ خطأ أثناء تحديث المهام."

  echo
  echo "[C] حالة المهام بعد التحديث:"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT id,actor,scope,status,priority,title,created_at,updated_at
    FROM tasks
    ORDER BY id;
  " || echo "⚠️ خطأ أثناء قراءة المهام بعد التحديث."
}

# ------------------------------------------------------
# 5) تنفيذ المرحلة بالكامل
# ------------------------------------------------------
init_quality_db
init_errors_db
init_learning_db
update_tasks_status

# ------------------------------------------------------
# 6) ملخص
# ------------------------------------------------------
sep "5) ملخص HF Stage 4 – Quality / Errors / Learning"

echo "ROOT        : $HYPER_ROOT"
echo "LOG_FILE    : $LOG_FILE"
echo "QUALITY_DB  : $QUALITY_DB"
echo "ERRORS_DB   : $ERRORS_DB"
echo "LEARNING_DB : $LEARNING_DB"
echo "TASKS_DB    : $TASKS_DB"
echo
echo "✅ Stage 4 مكتمل على مستوى:"
echo "   - إنشاء hf_quality.db / hf_errors.db / hf_learning.db مع جداول أساسية."
echo "   - ربط المهام quality_system / errors_system / learning_system بحالة DONE داخل hf_tasks.db."
