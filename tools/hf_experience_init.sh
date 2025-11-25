#!/usr/bin/env bash
# HyperFFactory – Experience System Init/Refresh
# - يحسب خبرة كل Actor من hf_tasks.db ويخزنها في hf_actors.db
# - لا يحذف أي مهام/أخطاء؛ فقط جدول إحصائي hf_actor_stats

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_ACTORS="$META_DIR/hf_actors.db"
DB_TASKS="$META_DIR/hf_tasks.db"

ts() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

log() {
  local level="$1"; shift
  echo "$(ts) [EXPERIENCE] [$level] $*"
}

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR" "sqlite3 غير متوفر في النظام."
  exit 1
fi

log "INFO" "HyperFFactory – Experience Init/Refresh"
log "INFO" "ROOT      = $ROOT"
log "INFO" "META_DIR  = $META_DIR"
log "INFO" "DB_ACTORS = $DB_ACTORS"
log "INFO" "DB_TASKS  = $DB_TASKS"

if [ ! -f "$DB_TASKS" ]; then
  log "WARN" "hf_tasks.db غير موجود تحت $META_DIR – لا يمكن حساب الخبرة."
  exit 0
fi

if [ ! -f "$DB_ACTORS" ]; then
  log "INFO" "hf_actors.db غير موجود – سيتم إنشاؤه."
  sqlite3 "$DB_ACTORS" "VACUUM;"
fi

# نبني/نحدّث جدول إحصائيات الخبرة داخل hf_actors.db
sqlite3 "$DB_ACTORS" <<SQL
PRAGMA foreign_keys = OFF;

-- جدول إحصائيات الخبرة لكل Actor
CREATE TABLE IF NOT EXISTS hf_actor_stats (
  actor            TEXT PRIMARY KEY,
  runs_total       INTEGER NOT NULL DEFAULT 0,
  runs_success     INTEGER NOT NULL DEFAULT 0,
  runs_failed      INTEGER NOT NULL DEFAULT 0,
  last_success_at  TEXT,
  last_failed_at   TEXT,
  success_rate     REAL  NOT NULL DEFAULT 0.0,
  experience_level TEXT  NOT NULL DEFAULT 'NEW',
  updated_at       TEXT  NOT NULL
);

-- إفراغ الجدول وإعادة احتسابه بالكامل (إحصائيات مشتقة فقط)
DELETE FROM hf_actor_stats;

ATTACH DATABASE '$DB_TASKS' AS tasksdb;

-- إدراج إحصائيات الخبرة من tasksdb.tasks
INSERT INTO hf_actor_stats (
  actor,
  runs_total,
  runs_success,
  runs_failed,
  last_success_at,
  last_failed_at,
  success_rate,
  experience_level,
  updated_at
)
SELECT
  actor,
  SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) AS runs_total,
  SUM(CASE WHEN status = 'DONE'  THEN 1 ELSE 0 END)            AS runs_success,
  SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END)           AS runs_failed,
  MAX(CASE WHEN status = 'DONE'   THEN updated_at ELSE NULL END) AS last_success_at,
  MAX(CASE WHEN status = 'FAILED' THEN updated_at ELSE NULL END) AS last_failed_at,
  CASE
    WHEN SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) = 0
      THEN 0.0
    ELSE ROUND(
      SUM(CASE WHEN status = 'DONE' THEN 1 ELSE 0 END) * 100.0 /
      SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END),
      2
    )
  END AS success_rate,
  CASE
    WHEN SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) >= 50
         AND (
           SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) = 0
           OR SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) > 0
         )
         AND (
           1 = 1
         )
         AND (
           SUM(CASE WHEN status = 'DONE' THEN 1 ELSE 0 END) * 100.0 /
           MAX(1, SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END))
         ) >= 90.0
      THEN 'EXPERT'
    WHEN SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) >= 20
         AND (
           SUM(CASE WHEN status = 'DONE' THEN 1 ELSE 0 END) * 100.0 /
           MAX(1, SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END))
         ) >= 70.0
      THEN 'STABLE'
    WHEN SUM(CASE WHEN status IN ('DONE','FAILED') THEN 1 ELSE 0 END) >= 5
      THEN 'NOVICE'
    ELSE 'NEW'
  END AS experience_level,
  datetime('now')
FROM tasksdb.tasks
GROUP BY actor;

DETACH DATABASE tasksdb;
SQL

log "INFO" "تم تحديث hf_actor_stats من hf_tasks.db بنجاح."
