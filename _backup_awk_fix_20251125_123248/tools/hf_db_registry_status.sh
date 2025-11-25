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

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت على النظام."
  exit 1
fi

echo
echo "========== [1] Discovery: Registry DBs =========="
REG_DBS="$(find "$META_DIR" -maxdepth 1 -type f -name '*registry*.db' 2>/dev/null | sort || true)"

if [ -z "$REG_DBS" ]; then
  echo "⚠️ لا توجد ملفات *.db تحتوي على 'registry' داخل $META_DIR"
else
  echo "📦 Registry DB files found:"
  echo "$REG_DBS" | sed 's/^/  - /'
  echo

  while IFS= read -r DB_PATH; do
    [ -z "$DB_PATH" ] && continue
    echo "-----------------------------------------------------"
    echo "REGISTRY DB : $DB_PATH"
    if [ -f "$DB_PATH" ]; then
      SIZE_BYTES=$(stat -c '%s' "$DB_PATH" 2>/dev/null || echo "?")
      MTIME=$(stat -c '%y' "$DB_PATH" 2>/dev/null || echo "?")
      echo "  • الحجم    : $SIZE_BYTES bytes"
      echo "  • آخر تعديل: $MTIME"
    fi

    echo "  • الجداول:"
    TABLES="$(sqlite3 "$DB_PATH" '.tables' 2>/dev/null || true)"
    if [ -z "$TABLES" ]; then
      echo "    (لا توجد جداول)"
    else
      echo "$TABLES" | sed 's/^/    - /'
      echo

      for T in $TABLES; do
        echo "    ▶ جدول: $T"
        echo "      schema:"
        sqlite3 "$DB_PATH" "PRAGMA table_info('$T');" 2>/dev/null \
          | sed 's/^/        /' || echo "        ⚠️ فشل في قراءة schema"
        CNT="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM \"$T\";" 2>/dev/null || echo "?")"
        echo "      rows: $CNT"
        echo
      done
    fi
  done <<< "$REG_DBS"
fi

echo
echo "========== [2] Discovery: Index DBs =========="
IDX_DBS="$(find "$META_DIR" -maxdepth 1 -type f -name '*index*.db' 2>/dev/null | sort || true)"

if [ -z "$IDX_DBS" ]; then
  echo "⚠️ لا توجد ملفات *.db تحتوي على 'index' داخل $META_DIR"
else
  echo "📦 Index DB files found:"
  echo "$IDX_DBS" | sed 's/^/  - /'
  echo

  while IFS= read -r DB_PATH; do
    [ -z "$DB_PATH" ] && continue
    echo "-----------------------------------------------------"
    echo "INDEX DB    : $DB_PATH"
    if [ -f "$DB_PATH" ]; then
      SIZE_BYTES=$(stat -c '%s' "$DB_PATH" 2>/dev/null || echo "?")
      MTIME=$(stat -c '%y' "$DB_PATH" 2>/dev/null || echo "?")
      echo "  • الحجم    : $SIZE_BYTES bytes"
      echo "  • آخر تعديل: $MTIME"
    fi

    echo "  • الجداول:"
    TABLES="$(sqlite3 "$DB_PATH" '.tables' 2>/dev/null || true)"
    if [ -z "$TABLES" ]; then
      echo "    (لا توجد جداول)"
    else
      echo "$TABLES" | sed 's/^/    - /'
      echo

      for T in $TABLES; do
        echo "    ▶ جدول: $T"
        echo "      schema:"
        sqlite3 "$DB_PATH" "PRAGMA table_info('$T');" 2>/dev/null \
          | sed 's/^/        /' || echo "        ⚠️ فشل في قراءة schema"
        CNT="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM \"$T\";" 2>/dev/null || echo "?")"
        echo "      rows: $CNT"
        echo
      done
    fi
  done <<< "$IDX_DBS"
fi

echo
echo "========== [3] ربط مع مهام hf_tasks.db (إن وجد) =========="
TASKS_DB="$META_DIR/hf_tasks.db"
if [ -f "$TASKS_DB" ]; then
  echo "📦 hf_tasks.db موجود: $TASKS_DB"
  # إصلاح awk – بدون backslashes
  sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null \
    | awk '{print "   → إجمالي المهام:", $1}' || echo "⚠️ تعذر قراءة عدد المهام."

  echo
  echo "   أهم المهام المتعلقة بالـ registry/index (إن وُجدت):"
  sqlite3 "$TASKS_DB" "
    SELECT id, actor, scope, status, priority
    FROM tasks
    WHERE scope LIKE 'db_manager:meta_dbs:rebuild_registry'
       OR scope LIKE 'db_manager:meta_dbs:rebuild_index'
       OR scope LIKE 'db_manager:meta_dbs:scan_meta_dbs'
    ORDER BY priority DESC, id
    LIMIT 30;
  " 2>/dev/null || echo "⚠️ لا توجد مهام بهذا الـ scope أو تعذر القراءة."
else
  echo "⚠️ لا يوجد hf_tasks.db تحت $META_DIR، تم تخطي ربط المهام."
fi

echo
echo "== END Registry / Index Status @ $TS =="
