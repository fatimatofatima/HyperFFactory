#!/usr/bin/env bash
# HyperFFactory - Add Task
# Usage: hf_tasks_add.sh <actor> <scope> <status> <priority> <title...>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_tasks.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "⚠️ قاعدة بيانات المهام غير موجودة: $DB"
  echo "▶ شغّل أولاً: bin/hf_tasks_init.sh" >&2
  exit 1
fi

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <actor> <scope> <status> <priority> <title...>" >&2
  echo "مثال: $0 hyper_brain_controller hyper PLANNED 1 \"فحص قواعد البيانات من meta\"" >&2
  exit 1
fi

ACTOR="$1"
SCOPE="$2"
STATUS="$3"
PRIORITY="$4"
shift 4
TITLE="$*"

# التحقق من صحة status
case "$STATUS" in
  PLANNED|RUNNING|DONE|FAILED|SKIPPED) ;;
  *)
    echo "❌ status غير صحيح: $STATUS (المسموح: PLANNED/RUNNING/DONE/FAILED/SKIPPED)" >&2
    exit 1
    ;;
esac

# التحقق من أولوية رقمية
if ! [[ "$PRIORITY" =~ ^[0-9]+$ ]]; then
  echo "❌ priority يجب أن يكون رقمًا صحيحًا: $PRIORITY" >&2
  exit 1
fi

TS="$(date '+%Y-%m-%d %H:%M:%S')"

# هروب apostrophe في العنوان
ESC_TITLE="${TITLE//\'/''}"
ESC_ACTOR="${ACTOR//\'/''}"
ESC_SCOPE="${SCOPE//\'/''}"

SQL="INSERT INTO tasks (actor,scope,title,status,priority,created_at,updated_at)
     VALUES ('$ESC_ACTOR','$ESC_SCOPE','$ESC_TITLE','$STATUS',$PRIORITY,'$TS','$TS');"

sqlite3 "$DB" "$SQL"

TASK_ID="$(sqlite3 "$DB" "SELECT last_insert_rowid();")"

echo "✅ تم إنشاء مهمة جديدة:"
echo "   id       : $TASK_ID"
echo "   actor    : $ACTOR"
echo "   scope    : $SCOPE"
echo "   status   : $STATUS"
echo "   priority : $PRIORITY"
echo "   title    : $TITLE"
echo "   ts       : $TS"

# تسجيل التقدّم في hf_changes.db إن وُجد hf_progress_log.sh
if [[ -x "$ROOT_DIR/bin/hf_progress_log.sh" ]]; then
  MSG="إنشاء مهمة جديدة (id=$TASK_ID, actor=$ACTOR, scope=$SCOPE, status=$STATUS, priority=$PRIORITY, title=$TITLE)"
  "$ROOT_DIR/bin/hf_progress_log.sh" "hf_tasks_add" "INFO" "$MSG" || true
fi
