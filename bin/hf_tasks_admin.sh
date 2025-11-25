#!/usr/bin/env bash
# HyperFFactory – Tasks Admin
# أوامر:
#   hf_tasks_admin.sh list
#   hf_tasks_admin.sh list actor <actor>
#   hf_tasks_admin.sh set-status <task_id> <NEW_STATUS> [note]
#   hf_tasks_admin.sh create "<actor>" "<title>" "<scope>" <priority> "[tags]"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

require_db "$HF_TASKS_DB"

LOG_SCRIPT="$SCRIPT_DIR/hf_tasks_log_change.sh"

find_tasks_table() {
  sqlite3 "$HF_TASKS_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('hf_tasks','tasks') LIMIT 1;"
}

has_column() {
  local db="$1" table="$2" col="$3"
  sqlite3 "$db" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

TASKS_TABLE="$(find_tasks_table)"

if [[ -z "$TASKS_TABLE" ]]; then
  echo "❌ لا يوجد جدول مهام (hf_tasks أو tasks) داخل $HF_TASKS_DB" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  hf_tasks_admin.sh list
  hf_tasks_admin.sh list actor <actor>
  hf_tasks_admin.sh set-status <task_id> <NEW_STATUS> [note]
  hf_tasks_admin.sh create "<actor>" "<title>" "<scope>" <priority> "[tags]"
USAGE
  exit 1
}

build_select_cols() {
  local cols desired all
  cols="$(sqlite3 "$HF_TASKS_DB" "PRAGMA table_info($TASKS_TABLE);" | awk -F'|' '{print $2}')"
  desired=(id actor title scope status priority created_at updated_at tags)
  all=""
  for c in "${desired[@]}"; do
    if echo "$cols" | grep -qx "$c"; then
      if [[ -z "$all" ]]; then
        all="$c"
      else
        all="$all, $c"
      fi
    fi
  done
  if [[ -z "$all" ]]; then
    all="*"
  fi
  echo "$all"
}

cmd="${1:-}"
[[ -z "$cmd" ]] && usage

case "$cmd" in
  list)
    shift
    SELECT_COLS="$(build_select_cols)"
    echo "====================================================="
    echo " HyperFFactory – Tasks List (all)"
    echo " DB   : $HF_TASKS_DB"
    echo " TABLE: $TASKS_TABLE"
    echo " TIME : $(date +"%Y-%m-%d %H:%M:%S %z")"
    echo "====================================================="
    if [[ "${1:-}" == "actor" && -n "${2:-}" && "$(has_column "$HF_TASKS_DB" "$TASKS_TABLE" "actor" && echo yes || echo no)" == "yes" ]]; then
      actor="$2"
      sqlite3 -header -column "$HF_TASKS_DB" "SELECT $SELECT_COLS FROM $TASKS_TABLE WHERE actor='$actor' ORDER BY id DESC LIMIT 100;"
    else
      sqlite3 -header -column "$HF_TASKS_DB" "SELECT $SELECT_COLS FROM $TASKS_TABLE ORDER BY id DESC LIMIT 100;"
    fi
    ;;

  set-status)
    shift
    [[ $# -lt 2 ]] && usage
    task_id="$1"
    new_status="$2"
    note="${3:-}"

    if ! has_column "$HF_TASKS_DB" "$TASKS_TABLE" "status"; then
      echo "❌ جدول $TASKS_TABLE لا يحتوي على عمود status" >&2
      exit 1
    fi

    # قراءة الحالة القديمة + actor إن وجد
    row="$(sqlite3 "$HF_TASKS_DB" "SELECT status$(has_column "$HF_TASKS_DB" "$TASKS_TABLE" "actor" && echo ',actor' || echo '') FROM $TASKS_TABLE WHERE id=$task_id;")" || true
    if [[ -z "$row" ]]; then
      echo "[ERROR] Task id=$task_id غير موجود داخل $HF_TASKS_DB ($TASKS_TABLE)" >&2
      exit 1
    fi

    old_status="${row%%|*}"
    actor=""
    if [[ "$row" == *"|"* ]]; then
      actor="${row#*|}"
    fi

    ts_local="$(date +"%Y-%m-%d %H:%M:%S %z")"

    if has_column "$HF_TASKS_DB" "$TASKS_TABLE" "updated_at"; then
      sqlite3 "$HF_TASKS_DB" <<SQL
UPDATE $TASKS_TABLE
SET status='$new_status',
    updated_at='$ts_local'
WHERE id=$task_id;
SQL
    else
      sqlite3 "$HF_TASKS_DB" <<SQL
UPDATE $TASKS_TABLE
SET status='$new_status'
WHERE id=$task_id;
SQL
    fi

    # تسجيل في سجل التغيّرات لو السكربت موجود
    if [[ -x "$LOG_SCRIPT" ]]; then
      "$LOG_SCRIPT" "$task_id" "${actor:-}" "$old_status" "$new_status" "$note" || true
    fi

    echo "✅ Updated task id=$task_id: $old_status → $new_status at $ts_local"
    ;;

  create)
    shift
    [[ $# -lt 4 ]] && usage
    actor="$1"
    title="$2"
    scope="$3"
    priority="$4"
    tags="${5:-}"
    status="PLANNED"
    ts_local="$(date +"%Y-%m-%d %H:%M:%S %z")"

    # الأعمدة الموجودة فعليًا
    cols_list="$(sqlite3 "$HF_TASKS_DB" "PRAGMA table_info($TASKS_TABLE);" | awk -F'|' '{print $2}')"

    fields=()
    values=()

    if echo "$cols_list" | grep -qx "actor"; then
      fields+=("actor")
      values+=("$(echo "$actor" | sed "s/'/''/g")")
    fi
    if echo "$cols_list" | grep -qx "title"; then
      fields+=("title")
      values+=("$(echo "$title" | sed "s/'/''/g")")
    fi
    if echo "$cols_list" | grep -qx "scope"; then
      fields+=("scope")
      values+=("$(echo "$scope" | sed "s/'/''/g")")
    fi
    if echo "$cols_list" | grep -qx "status"; then
      fields+=("status")
      values+=("$status")
    fi
    if echo "$cols_list" | grep -qx "priority"; then
      fields+=("priority")
      values+=("$priority")
    fi
    if echo "$cols_list" | grep -qx "tags"; then
      fields+=("tags")
      values+=("$(echo "$tags" | sed "s/'/''/g")")
    fi
    if echo "$cols_list" | grep -qx "created_at"; then
      fields+=("created_at")
      values+=("$ts_local")
    fi
    if echo "$cols_list" | grep -qx "updated_at"; then
      fields+=("updated_at")
      values+=("$ts_local")
    fi

    if [[ "${#fields[@]}" -eq 0 ]]; then
      echo "❌ لا توجد أعمدة مناسبة لإدخال مهمة جديدة داخل $TASKS_TABLE" >&2
      exit 1
    fi

    # بناء INSERT ديناميكي
    fields_csv=""
    values_csv=""
    for i in "${!fields[@]}"; do
      f="${fields[$i]}"
      v="${values[$i]}"
      if [[ -z "$fields_csv" ]]; then
        fields_csv="$f"
        values_csv="'$v'"
      else
        fields_csv="$fields_csv, $f"
        values_csv="$values_csv, '$v'"
      fi
    done

    sqlite3 "$HF_TASKS_DB" <<SQL
INSERT INTO $TASKS_TABLE ($fields_csv)
VALUES ($values_csv);
SQL

    new_id="$(sqlite3 "$HF_TASKS_DB" "SELECT last_insert_rowid();")"
    echo "✅ Created task id=$new_id actor=$actor status=$status priority=$priority (table=$TASKS_TABLE)"
    ;;

  *)
    usage
    ;;
esac
