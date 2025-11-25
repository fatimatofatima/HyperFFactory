#!/usr/bin/env bash
# HyperFFactory – Tasks Changes Logger
# usage:
#   bin/hf_tasks_log_change.sh <TASK_ID> "<ACTOR>" "<OLD_STATUS>" "<NEW_STATUS>" "[NOTE]"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

mkdir -p "$(dirname "$HF_CHANGES_DB")"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <TASK_ID> \"<ACTOR>\" \"<OLD_STATUS>\" \"<NEW_STATUS>\" \"[NOTE]\"" >&2
  exit 1
fi

TASK_ID="$1"
ACTOR="$2"
OLD_STATUS="$3"
NEW_STATUS="$4"
NOTE="${5:-}"

TS="$(ts_now)"

# إنشاء جدول خاص بتغييرات المهام لو غير موجود
sqlite3 "$HF_CHANGES_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS hf_task_changes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id    INTEGER NOT NULL,
  actor      TEXT,
  old_status TEXT,
  new_status TEXT,
  note       TEXT,
  ts         TEXT NOT NULL
);
SQL

# إدخال السطر الجديد
sqlite3 "$HF_CHANGES_DB" <<SQL
INSERT INTO hf_task_changes (task_id, actor, old_status, new_status, note, ts)
VALUES (
  $TASK_ID,
  '$(echo "$ACTOR" | sed "s/'/''/g")',
  '$(echo "$OLD_STATUS" | sed "s/'/''/g")',
  '$(echo "$NEW_STATUS" | sed "s/'/''/g")',
  '$(echo "$NOTE" | sed "s/'/''/g")',
  '$TS'
);
SQL

echo "[TASKS-CHANGE] $TS task_id=$TASK_ID actor=$ACTOR $OLD_STATUS -> $NEW_STATUS note=$NOTE"
