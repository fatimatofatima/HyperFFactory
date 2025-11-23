#!/usr/bin/env bash
# HyperFFactory - Register Scripts as PLANNED Tasks
# يسجّل سكربتات bin/ و workers/ في جدول tasks بدون تشغيلها

set -euo pipefail

ROOT="/root/HyperFFactory"
DB="$ROOT/db/meta/hf_ops_meta.db"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_register_scripts_as_tasks_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HF REGISTER SCRIPTS AS TASKS START"
log "ROOT = $ROOT"
log "DB   = $DB"
log "=================================================="

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 غير مثبت."
  exit 1
fi

sql_escape() {
  echo "$1" | sed "s/'/''/g"
}

SCRIPTS=$(find "$ROOT/bin" "$ROOT/workers" -maxdepth 1 -type f -name '*.sh' -perm -u+x 2>/dev/null || true)

if [ -z "$SCRIPTS" ]; then
  log "لا يوجد سكربتات تنفيذية (*.sh) في bin/ أو workers/."
  exit 0
fi

COUNT_NEW=0
COUNT_EXIST=0

for s in $SCRIPTS; do
  ACTOR=$(basename "$s")
  SCOPE="$s"

  ACTOR_ESC=$(sql_escape "$ACTOR")
  SCOPE_ESC=$(sql_escape "$SCOPE")

  EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE scope = '$SCOPE_ESC';")
  if [ "$EXISTS" != "0" ]; then
    log "TASK EXISTS: scope=$SCOPE (actor=$ACTOR)"
    COUNT_EXIST=$((COUNT_EXIST+1))
    continue
  fi

  sqlite3 "$DB" <<SQL
INSERT INTO tasks (actor, scope, status, priority, created_at, updated_at)
VALUES ('$ACTOR_ESC', '$SCOPE_ESC', 'PLANNED', 1, datetime('now'), datetime('now'));
SQL

  sqlite3 "$DB" <<SQL
INSERT INTO progress_log (script_name, action, path, status, details, ts)
VALUES ('hf_register_scripts_as_tasks.sh', 'REGISTER', '$SCOPE_ESC', 'PLANNED', 'actor=$ACTOR_ESC', datetime('now'));
SQL

  log "TASK ADDED : scope=$SCOPE (actor=$ACTOR)"
  COUNT_NEW=$((COUNT_NEW+1))
done

log "--------------------------------------------------"
log "TASKS NEW     = $COUNT_NEW"
log "TASKS EXISTED = $COUNT_EXIST"
log "=================================================="
log "HF REGISTER SCRIPTS AS TASKS DONE"
log "LOG = $LOG"
log "=================================================="
