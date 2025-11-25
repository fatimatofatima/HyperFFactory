#!/usr/bin/env bash
# HyperFFactory – Experience Report
# - يقرأ من hf_actors.db / hf_actor_stats فقط (READ-ONLY)
# - لا يغيّر أي قواعد بيانات

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_ACTORS="$META_DIR/hf_actors.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

log() {
  local level="$1"; shift
  echo "$(ts) [EXPERIENCE] [$level] $*"
}

echo "====================================================="
echo " HyperFFactory – Experience & Skills Report"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " TIME : $(ts)"
echo "====================================================="

if [ ! -f "$DB_ACTORS" ]; then
  log "WARN" "hf_actors.db غير موجود تحت $META_DIR – لا يوجد نظام خبرة بعد."
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR" "sqlite3 غير متوفر."
  exit 1
fi

echo
echo "---------- [1] Summary per Actor (hf_actor_stats) ----------"

sqlite3 -header -column "$DB_ACTORS" <<'SQL'
SELECT
  actor,
  runs_total,
  runs_success,
  runs_failed,
  success_rate,
  experience_level,
  last_success_at,
  last_failed_at,
  updated_at
FROM hf_actor_stats
ORDER BY experience_level DESC, success_rate DESC, runs_total DESC, actor;
SQL

echo
echo "---------- [2] Top Failing Actors (by runs_failed DESC) ----------"

sqlite3 -header -column "$DB_ACTORS" <<'SQL'
SELECT
  actor,
  runs_failed,
  runs_total,
  success_rate,
  experience_level
FROM hf_actor_stats
WHERE runs_failed > 0
ORDER BY runs_failed DESC, success_rate ASC
LIMIT 10;
SQL
