#!/usr/bin/env bash
# HyperFFactory – Registry / Index Status
# - READ-ONLY على كل قواعد البيانات
# - يلتزم بالـ Unified Tree Policy (كل شيء تحت /root/HyperFFactory)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
TS="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "====================================================="
echo " HyperFFactory – Registry / Index DB Status"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " TIME : $TS"
echo "====================================================="
echo

############################
# [1] Registry DBs
############################
echo "========== [1] Discovery: Registry DBs =========="
mapfile -t REG_DBS < <(find "$META_DIR" -maxdepth 1 -type f -name '*registry*.db' | sort || true)

if ((${#REG_DBS[@]} == 0)); then
  echo "⚠️ لا توجد ملفات *.db تحتوي على 'registry' في $META_DIR"
else
  for db in "${REG_DBS[@]}"; do
    echo "-----------------------------------------------------"
    echo "REGISTRY DB : $db"

    size=$(stat -c '%s' "$db" 2>/dev/null || echo "?")
    mtime=$(stat -c '%y' "$db" 2>/dev/null || echo "?")
    echo "  • الحجم    : ${size} bytes"
    echo "  • آخر تعديل: $mtime"

    echo "  • الجداول:"
    tables=$(sqlite3 "$db" ".tables" 2>/dev/null || echo "")
    if [[ -z "$tables" ]]; then
      echo "    (لا توجد جداول)"
    else
      echo "    - $tables"
      echo
      for t in $tables; do
        echo "    ▶ جدول: $t"
        echo "      schema:"
        sqlite3 "$db" "PRAGMA table_info($t);" 2>/dev/null | while IFS='|' read -r cid name type notnull dflt pk; do
          echo "        $cid|$name|$type|$notnull|$dflt|$pk"
        done

        cnt=$(sqlite3 "$db" "SELECT COUNT(*) FROM $t;" 2>/dev/null || echo "0")
        echo "      → عدد الصفوف: $cnt"
        echo
      done
    fi
  done
fi

echo
############################
# [2] Index DBs
############################
echo "========== [2] Discovery: Index DBs =========="
mapfile -t IDX_DBS < <(find "$META_DIR" -maxdepth 1 -type f -name '*index*.db' | sort || true)

if ((${#IDX_DBS[@]} == 0)); then
  echo "⚠️ لا توجد ملفات *.db تحتوي على 'index' في $META_DIR"
else
  for db in "${IDX_DBS[@]}"; do
    echo "-----------------------------------------------------"
    echo "INDEX DB    : $db"

    size=$(stat -c '%s' "$db" 2>/dev/null || echo "?")
    mtime=$(stat -c '%y' "$db" 2>/dev/null || echo "?")
    echo "  • الحجم    : ${size} bytes"
    echo "  • آخر تعديل: $mtime"

    echo "  • الجداول:"
    tables=$(sqlite3 "$db" ".tables" 2>/dev/null || echo "")
    if [[ -z "$tables" ]]; then
      echo "    (لا توجد جداول)"
    else
      echo "    - $tables"
      echo
      for t in $tables; do
        echo "    ▶ جدول: $t"
        echo "      schema:"
        sqlite3 "$db" "PRAGMA table_info($t);" 2>/dev/null | while IFS='|' read -r cid name type notnull dflt pk; do
          echo "        $cid|$name|$type|$notnull|$dflt|$pk"
        done

        cnt=$(sqlite3 "$db" "SELECT COUNT(*) FROM $t;" 2>/dev/null || echo "0")
        echo "      → عدد الصفوف: $cnt"
        echo
      done
    fi
  done
fi

############################
# [3] Tasks Snapshot (اختياري للربط مع db_manager)
############################
TASKS_DB="$META_DIR/hf_tasks.db"
if [[ -f "$TASKS_DB" ]]; then
  echo
  echo "========== [3] Tasks Snapshot (hf_tasks.db) =========="
  total=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
  planned=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='PLANNED';" 2>/dev/null || echo "0")
  done_cnt=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='DONE';" 2>/dev/null || echo "0")
  running=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='RUNNING';" 2>/dev/null || echo "0")

  echo "إجمالي المهام   : $total"
  echo "PLANNED         : $planned"
  echo "DONE            : $done_cnt"
  echo "RUNNING         : $running"
  echo
  echo "أعلى 5 مهام PLANNED (hf_db_manager / registry / meta_dbs):"
  sqlite3 -csv "$TASKS_DB" "
    SELECT id,actor,scope,priority,status
    FROM tasks
    WHERE actor='hf_db_manager'
      AND (scope LIKE 'db_manager:meta_dbs:%' OR scope LIKE 'db_manager:registry:%')
      AND status='PLANNED'
    ORDER BY priority DESC, id ASC
    LIMIT 5;
  " 2>/dev/null | while IFS=',' read -r id actor scope priority status; do
    echo "  $id|$actor|$scope|$priority|$status"
  done
else
  echo
  echo "========== [3] Tasks Snapshot =========="
  echo "⚠️ لا يوجد hf_tasks.db تحت $META_DIR، تخطّي ملخّص المهام."
fi
