#!/usr/bin/env bash
# HyperFFactory – Management Cycle with Tasks & Quality Logging
# Wrapper فوق scripts/hf_management_smart_run.sh
# - يسجل مهمة في hf_ops_meta.db (tasks)
# - يسجل فحص جودة في hf_quality.db (quality_events)
# - لا يلمس /opt/ffactory أو /opt/smartfriend-suite مباشرة

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

DB_DIR="$ROOT/db/meta"
OPS_DB="$DB_DIR/hf_ops_meta.db"
QUALITY_DB="$DB_DIR/hf_quality.db"

mkdir -p "$DB_DIR" reports

TS_RUN="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="reports/management_with_tasks_${TS_RUN}.log"

log() {
    echo "[$(date +%Y%m%d_%H%M%S)] $*" | tee -a "$LOG_FILE"
}

now() {
    date '+%Y-%m-%d %H:%M:%S'
}

ensure_sqlite() {
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log "[ERROR] sqlite3 غير متوفر في النظام – لا يمكن تسجيل المهام والجودة."
        exit 1
    fi
}

init_ops_db() {
    log "[DB] init_ops_db → $OPS_DB"
    sqlite3 "$OPS_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS tasks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    actor       TEXT NOT NULL,
    scope       TEXT NOT NULL,
    status      TEXT NOT NULL,
    priority    INTEGER DEFAULT 5,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
SQL
}

init_quality_db() {
    log "[DB] init_quality_db → $QUALITY_DB"
    sqlite3 "$QUALITY_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS quality_events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    actor      TEXT NOT NULL,
    check_name TEXT NOT NULL,
    result     TEXT NOT NULL,
    score      INTEGER NOT NULL,
    details    TEXT,
    ts         TEXT NOT NULL
);
SQL
}

create_task() {
    local actor="$1"
    local scope="$2"
    local status="RUNNING"
    local priority="${3:-5}"
    local ts
    ts="$(now)"

    log "[TASK] إنشاء مهمة جديدة (actor=$actor, scope=$scope, status=$status, priority=$priority)"
    sqlite3 "$OPS_DB" <<SQL
INSERT INTO tasks (actor, scope, status, priority, created_at, updated_at)
VALUES (
    '$(printf "%s" "$actor" | sed "s/'/''/g")',
    '$(printf "%s" "$scope" | sed "s/'/''/g")',
    '$status',
    $priority,
    '$ts',
    '$ts'
);
SQL

    # إرجاع آخر ID
    sqlite3 "$OPS_DB" 'SELECT last_insert_rowid();'
}

update_task_status() {
    local task_id="$1"
    local new_status="$2"

    local ts
    ts="$(now)"
    log "[TASK] تحديث حالة المهمة id=$task_id → $new_status"

    sqlite3 "$OPS_DB" <<SQL
UPDATE tasks
   SET status = '$(printf "%s" "$new_status" | sed "s/'/''/g")',
       updated_at = '$ts'
 WHERE id = $task_id;
SQL
}

add_quality_event() {
    local actor="$1"
    local check_name="$2"
    local result="$3"
    local score="$4"
    local details="$5"
    local ts
    ts="$(now)"

    log "[QUALITY] تسجيل حدث جودة (actor=$actor, check=$check_name, result=$result, score=$score)"
    sqlite3 "$QUALITY_DB" <<SQL
INSERT INTO quality_events (actor, check_name, result, score, details, ts)
VALUES (
    '$(printf "%s" "$actor" | sed "s/'/''/g")',
    '$(printf "%s" "$check_name" | sed "s/'/''/g")',
    '$(printf "%s" "$result" | sed "s/'/''/g")',
    $score,
    '$(printf "%s" "$details" | sed "s/'/''/g")',
    '$ts'
);
SQL
}

main() {
    log "====================================================="
    log "HyperFFactory – Management With Tasks & Quality"
    log "ROOT : $ROOT"
    log "TIME : $TS_RUN"
    log "LOG  : $LOG_FILE"
    log "====================================================="

    ensure_sqlite
    init_ops_db
    init_quality_db

    local actor="hyper_management"
    local scope="management_cycle"
    local priority=5

    # إنشاء المهمة
    TASK_ID="$(create_task "$actor" "$scope" "$priority")"
    log "[TASK] task_id = $TASK_ID"

    # تشغيل سكربت الإدارة الأساسي
    log "[RUN] تشغيل scripts/hf_management_smart_run.sh ..."
    set +e
    scripts/hf_management_smart_run.sh
    EXIT_CODE=$?
    set -e
    log "[RUN] hf_management_smart_run.sh انتهى بكود: $EXIT_CODE"

    # تحديد الحالة والسكور
    local new_status result score details
    if [ "$EXIT_CODE" -eq 0 ]; then
        new_status="DONE"
        result="SUCCESS"
        score=100
    else
        new_status="FAILED"
        result="FAILURE"
        score=40
    fi
    details="hf_management_smart_run.sh exit_code=$EXIT_CODE"

    # تحديث المهمة
    update_task_status "$TASK_ID" "$new_status"

    # تسجيل الجودة
    add_quality_event "$actor" "management_cycle_full" "$result" "$score" "$details"

    log "====================================================="
    log "Management With Tasks & Quality انتهت (status=$new_status, exit=$EXIT_CODE)"
    log "====================================================="

    exit "$EXIT_CODE"
}

main "$@"
