#!/usr/bin/env bash
# HyperFFactory – Status Snapshot
# - يُستخدم بواسطة hf_dashboard_cli.sh و hyper_guard
# - READ-ONLY على قواعد البيانات
# - لا يغيّر أي شيء (مجرد تقرير سريع)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

echo "=================================================="
echo " HyperFFactory – Status Snapshot"
echo " ROOT : $ROOT"
echo " META : $META_DIR"
echo " TIME : $(ts)"
echo "=================================================="

#----------------------------------
# 1) ملخص المهام من hf_tasks.db
#----------------------------------
TASKS_DB="$META_DIR/hf_tasks.db"
if [ -f "$TASKS_DB" ]; then
  echo
  echo "---------- [1] Tasks Summary (hf_tasks.db) ----------"
  if command -v sqlite3 >/dev/null 2>&1; then
    TOTAL=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "?")
    PLANNED=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='PLANNED';" 2>/dev/null || echo "?")
    DONE=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='DONE';" 2>/dev/null || echo "?")
    RUNNING=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='RUNNING';" 2>/dev/null || echo "?")
    echo "إجمالي المهام   : $TOTAL"
    echo "PLANNED         : $PLANNED"
    echo "DONE            : $DONE"
    echo "RUNNING         : $RUNNING"

    echo
    echo "أعلى 5 مهام PLANNED (حسب الأولوية):"
    sqlite3 "$TASKS_DB" "
      SELECT id, actor, scope, priority, status
      FROM tasks
      WHERE status='PLANNED'
      ORDER BY priority DESC, id ASC
      LIMIT 5;
    " 2>/dev/null || echo "⚠️ تعذر قراءة تفاصيل المهام."
  else
    echo "⚠️ sqlite3 غير متوفر، لا يمكن قراءة المهام."
  fi
else
  echo
  echo "⚠️ لا يوجد hf_tasks.db في $META_DIR"
fi

#----------------------------------
# 2) ملخص الأخطاء من hf_errors.db
#----------------------------------
ERRORS_DB="$META_DIR/hf_errors.db"
if [ -f "$ERRORS_DB" ]; then
  echo
  echo "---------- [2] Errors Summary (hf_errors.db) ----------"
  if command -v sqlite3 >/dev/null 2>&1; then
    # نحاول اكتشاف جدول errors أو incidents
    ERR_TABLE=$(sqlite3 "$ERRORS_DB" "
      SELECT name FROM sqlite_master
      WHERE type='table' AND name IN ('errors','incidents')
      LIMIT 1;
    " 2>/dev/null || true)

    if [ -n "$ERR_TABLE" ]; then
      TOTAL_ERR=$(sqlite3 "$ERRORS_DB" "SELECT COUNT(*) FROM $ERR_TABLE;" 2>/dev/null || echo "?")
      echo "جدول الأخطاء المستخدم : $ERR_TABLE"
      echo "إجمالي الحوادث        : $TOTAL_ERR"

      echo
      echo "آخر 5 حوادث:"
      # نحاول أعمدة عامة: id, actor, error_type, severity, ts
      sqlite3 "$ERRORS_DB" "
        SELECT id, actor, error_type, severity, ts
        FROM $ERR_TABLE
        ORDER BY id DESC
        LIMIT 5;
      " 2>/dev/null || echo "⚠️ تعذر قراءة تفاصيل الحوادث (schema مختلف)."
    else
      echo "⚠️ لا يوجد جدول errors/incidents داخل hf_errors.db."
    fi
  else
    echo "⚠️ sqlite3 غير متوفر، لا يمكن قراءة الأخطاء."
  fi
else
  echo
  echo "⚠️ لا يوجد hf_errors.db في $META_DIR"
fi

#----------------------------------
# 3) ملخص الجودة من hf_quality.db (اختياري)
#----------------------------------
QUALITY_DB="$META_DIR/hf_quality.db"
if [ -f "$QUALITY_DB" ]; then
  echo
  echo "---------- [3] Quality Summary (hf_quality.db) ----------"
  if command -v sqlite3 >/dev/null 2>&1; then
    Q_TABLE=$(sqlite3 "$QUALITY_DB" "
      SELECT name FROM sqlite_master
      WHERE type='table' AND name IN ('quality_checks','checks')
      LIMIT 1;
    " 2>/dev/null || true)

    if [ -n "$Q_TABLE" ]; then
      TOTAL_Q=$(sqlite3 "$QUALITY_DB" "SELECT COUNT(*) FROM $Q_TABLE;" 2>/dev/null || echo "?")
      echo "جدول الجودة المستخدم : $Q_TABLE"
      echo "إجمالي سجلات الجودة : $TOTAL_Q"

      echo
      echo "آخر 5 سجلات جودة:"
      # نحاول أعمدة عامة: id, check_name, score, ts
      sqlite3 "$QUALITY_DB" "
        SELECT id, check_name, score, ts
        FROM $Q_TABLE
        ORDER BY id DESC
        LIMIT 5;
      " 2>/dev/null || echo "⚠️ تعذر قراءة تفاصيل الجودة (schema مختلف)."
    else
      echo "⚠️ لا يوجد جدول quality_checks/checks داخل hf_quality.db."
    fi
  else
    echo "⚠️ sqlite3 غير متوفر، لا يمكن قراءة الجودة."
  fi
else
  echo
  echo "⚠️ لا يوجد hf_quality.db في $META_DIR"
fi

#----------------------------------
# 4) Snapshot سريع للـ Registry (hf_registry.db) – READ-ONLY
#----------------------------------
REG_DB="$META_DIR/hf_registry.db"
if [ -f "$REG_DB" ]; then
  echo
  echo "---------- [4] Registry Snapshot (hf_registry.db) ----------"
  if command -v sqlite3 >/dev/null 2>&1; then
    # نحاول جدول db_registry إن وجد
    HAVE_DB_REG=$(sqlite3 "$REG_DB" "
      SELECT name FROM sqlite_master
      WHERE type='table' AND name='db_registry'
      LIMIT 1;
    " 2>/dev/null || true)

    if [ -n "$HAVE_DB_REG" ]; then
      CNT_REG=$(sqlite3 "$REG_DB" "SELECT COUNT(*) FROM db_registry;" 2>/dev/null || echo "?")
      echo "db_registry rows : $CNT_REG"
    else
      echo "⚠️ لا يوجد جدول db_registry داخل hf_registry.db."
    fi

    # scripts_registry (اختياري)
    HAVE_SCR_REG=$(sqlite3 "$REG_DB" "
      SELECT name FROM sqlite_master
      WHERE type='table' AND name='scripts_registry'
      LIMIT 1;
    " 2>/dev/null || true)

    if [ -n "$HAVE_SCR_REG" ]; then
      CNT_SCR=$(sqlite3 "$REG_DB" "SELECT COUNT(*) FROM scripts_registry;" 2>/dev/null || echo "?")
      echo "scripts_registry rows : $CNT_SCR"
    fi
  else
    echo "⚠️ sqlite3 غير متوفر، لا يمكن قراءة الريجستري."
  fi
else
  echo
  echo "⚠️ لا يوجد hf_registry.db في $META_DIR"
fi

#----------------------------------
# 5) Docker Snapshot (اختياري – لو docker موجود)
#----------------------------------
if command -v docker >/dev/null 2>&1; then
  echo
  echo "---------- [5] Docker Snapshot ----------"
  docker ps --format 'NAME={{.Names}}  IMAGE={{.Image}}  STATUS={{.Status}}  PORTS={{.Ports}}' \
    | head -n 10 || echo "⚠️ تعذر قراءة docker ps."
else
  echo
  echo "⚠️ docker غير متوفر، تخطي Snapshot الحاويات."
fi

echo
echo "== END Status Snapshot @ $(ts) =="
