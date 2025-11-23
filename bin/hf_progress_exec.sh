#!/usr/bin/env bash
# HyperFFactory - Progress Exec Wrapper
# يشغّل أي أمر داخل الهيكل مع تسجيل:
# tasks + progress_log + experiences + incidents

set -euo pipefail

ROOT="/root/HyperFFactory"
DB="$ROOT/db/meta/hf_ops_meta.db"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_progress_exec_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

if [ $# -lt 3 ]; then
  echo "Usage: hf_progress_exec.sh <ACTOR> <SCOPE> <COMMAND...>" >&2
  exit 1
fi

ACTOR="$1"
SCOPE="$2"
shift 2
CMD="$*"

log "=================================================="
log "HF PROGRESS EXEC START"
log "ACTOR = $ACTOR"
log "SCOPE = $SCOPE"
log "CMD   = $CMD"
log "DB    = $DB"
log "=================================================="

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 غير مثبت."
  exit 1
fi

sql_escape() {
  # بسيط: استبدال ' بـ '' للسلامة في SQLite
  echo "$1" | sed "s/'/''/g"
}

ACTOR_ESC=$(sql_escape "$ACTOR")
SCOPE_ESC=$(sql_escape "$SCOPE")
CMD_ESC=$(sql_escape "$CMD")

# 1) إنشاء Task بحالة RUNNING
TASK_ID=$(sqlite3 "$DB" <<SQL
INSERT INTO tasks (actor, scope, status, priority, created_at, updated_at)
VALUES ('$ACTOR_ESC', '$SCOPE_ESC', 'RUNNING', 1, datetime('now'), datetime('now'));
SELECT last_insert_rowid();
SQL
)

log "TASK_ID = $TASK_ID (RUNNING)"

# 2) تسجيل START في progress_log
sqlite3 "$DB" <<SQL
INSERT INTO progress_log (script_name, action, path, status, details, ts)
VALUES ('hf_progress_exec.sh', 'START', '$SCOPE_ESC', 'RUNNING', '$CMD_ESC', datetime('now'));
SQL

# 3) تشغيل الأمر الفعلي
log "EXEC: $CMD"
set +e
bash -c "$CMD"
RC=$?
set -e

STATUS="DONE"
INCIDENT_ID=""
SEVERITY="LOW"

if [ $RC -ne 0 ]; then
  STATUS="FAILED"
  SEVERITY="MEDIUM"
fi

log "COMMAND EXIT CODE = $RC (STATUS = $STATUS)"

# 4) تحديث حالة الـ Task
sqlite3 "$DB" <<SQL
UPDATE tasks
SET status = '$STATUS',
    updated_at = datetime('now')
WHERE id = $TASK_ID;
SQL

# 5) تحديث خبرة الـ Actor في experiences
sqlite3 "$DB" <<SQL
INSERT INTO experiences (actor, runs_total, runs_success, runs_failed, success_rate, experience_level)
VALUES ('$ACTOR_ESC', 1, CASE WHEN '$STATUS'='DONE' THEN 1 ELSE 0 END,
              CASE WHEN '$STATUS'='FAILED' THEN 1 ELSE 0 END,
              CASE WHEN '$STATUS'='DONE' THEN 100.0 ELSE 0.0 END,
              'NOVICE')
ON CONFLICT(actor)
DO UPDATE SET
  runs_total   = runs_total + 1,
  runs_success = runs_success + CASE WHEN excluded.runs_success=1 THEN 1 ELSE 0 END,
  runs_failed  = runs_failed  + CASE WHEN excluded.runs_failed=1 THEN 1 ELSE 0 END,
  success_rate = CASE
                   WHEN (runs_total + 1) > 0
                   THEN ROUND(100.0 * (runs_success + CASE WHEN excluded.runs_success=1 THEN 1 ELSE 0 END) / (runs_total + 1), 2)
                   ELSE success_rate
                 END,
  experience_level = CASE
                       WHEN success_rate >= 90 THEN 'EXPERT'
                       WHEN success_rate >= 60 THEN 'STABLE'
                       ELSE 'NOVICE'
                     END;
SQL

# 6) تسجيل Incident في حالة الفشل
if [ "$STATUS" = "FAILED" ]; then
  MSG_ESC=$(sql_escape "CMD failed with exit code $RC")
  sqlite3 "$DB" <<SQL
INSERT INTO incidents (actor, error_type, error_message, severity, ts, context)
VALUES ('$ACTOR_ESC', 'COMMAND_FAILURE', '$MSG_ESC', '$SEVERITY', datetime('now'), '$CMD_ESC');
SQL
  log "INCIDENT recorded for ACTOR=$ACTOR STATUS=FAILED"
fi

# 7) تسجيل END في progress_log
sqlite3 "$DB" <<SQL
INSERT INTO progress_log (script_name, action, path, status, details, ts)
VALUES ('hf_progress_exec.sh', 'END', '$SCOPE_ESC', '$STATUS', 'RC=$RC', datetime('now'));
SQL

log "=================================================="
log "HF PROGRESS EXEC DONE (STATUS=$STATUS, RC=$RC)"
log "LOG = $LOG"
log "=================================================="

exit $RC
