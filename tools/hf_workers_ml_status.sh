#!/usr/bin/env bash
# HyperFFactory – Workers & ML Status
# - READ-ONLY: لا يغير أي قواعد بيانات، فقط تقارير.
# - يفحص:
#   1) مهام التعلّم والعمال في hf_tasks.db
#   2) جداول وأعداد hf_actors.db (لو موجود)
#   3) جداول وأعداد hf_learning.db (لو موجود)
#   4) الحاويات (Docker) ذات العلاقة بالـ AI/Workers

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

TASKS_DB="$META_DIR/hf_tasks.db"
ACTORS_DB="$META_DIR/hf_actors.db"
LEARNING_DB="$META_DIR/hf_learning.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

echo "====================================================="
echo " HyperFFactory – Workers & ML Status"
echo " ROOT  : $ROOT"
echo " META  : $META_DIR"
echo " TIME  : $(ts)"
echo "====================================================="
echo

########################################
# [1] مهام التعلّم والعمال (hf_tasks.db)
########################################
echo "---------- [1] Tasks related to Workers / Learning ----------"

if [ -f "$TASKS_DB" ]; then
  echo "[INFO] hf_tasks.db موجود: $TASKS_DB"
  echo

  echo "[A] ملخص الحالات (كل المهام):"
  if sqlite3 "$TASKS_DB" "SELECT status, COUNT(*) AS cnt FROM tasks GROUP BY status ORDER BY status;" \
      | awk -F'|' '
        BEGIN {
          printf "%-10s %s\n", "status", "cnt";
          print "---------- ----";
        }
        {
          printf "%-10s %s\n", $1, $2;
        }
      '; then
    :
  else
    echo "[WARN] تعذّر قراءة ملخص الحالات من hf_tasks.db"
  fi
  echo

  echo "[B] مهام لها علاقة بالتعلّم (learning):"
  if ! sqlite3 "$TASKS_DB" "
    SELECT id, actor, scope, status, priority, title
    FROM tasks
    WHERE actor LIKE '%learning%'
       OR scope LIKE '%learning%'
       OR title LIKE '%تعلّم%'
    ORDER BY id;
  "; then
    echo "[WARN] لا توجد مهام learning أو حدث خطأ في الاستعلام."
  fi
  echo

  echo "[C] مهام لها علاقة بالعمال / المدراء (workers / actors):"
  if ! sqlite3 "$TASKS_DB" "
    SELECT id, actor, scope, status, priority, title
    FROM tasks
    WHERE actor LIKE '%worker%'
       OR actor LIKE '%actor%'
       OR scope LIKE '%worker%'
    ORDER BY id;
  "; then
    echo "[WARN] لا توجد مهام workers/actors أو حدث خطأ في الاستعلام."
  fi
  echo
else
  echo "[WARN] لا يوجد hf_tasks.db تحت $META_DIR – لن يتم فحص المهام."
fi

echo

########################################
# [2] قاعدة بيانات العمال/الـ Actors
########################################
echo "---------- [2] Actors DB (hf_actors.db) ----------"

if [ -f "$ACTORS_DB" ]; then
  echo "[INFO] hf_actors.db موجود: $ACTORS_DB"
  echo "[INFO] الجداول الموجودة:"
  if sqlite3 "$ACTORS_DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" \
      | awk '{printf "  - %s\n",$1}'; then
    :
  else
    echo "[WARN] تعذّر قراءة قائمة الجداول من hf_actors.db"
  fi
  echo

  echo "[INFO] عدد الصفوف في كل جدول:"
  for tbl in $(sqlite3 "$ACTORS_DB" "SELECT name FROM sqlite_master WHERE type='table';"); do
    cnt=$(sqlite3 "$ACTORS_DB" "SELECT COUNT(*) FROM $tbl;" 2>/dev/null || echo "?")
    printf "  - %-25s : %s rows\n" "$tbl" "$cnt"
  done
  echo

  if sqlite3 "$ACTORS_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='hf_actors';" \
      | grep -q '^hf_actors$'; then
    echo "[INFO] أول 10 صفوف من جدول hf_actors:"
    sqlite3 "$ACTORS_DB" "SELECT * FROM hf_actors LIMIT 10;"
  else
    echo "[NOTE] لا يوجد جدول باسم 'hf_actors' – ربما يكون اسم آخر."
  fi
else
  echo "[WARN] لا يوجد hf_actors.db تحت $META_DIR – لن يتم فحص الـ Actors."
fi

echo

########################################
# [3] قاعدة بيانات التعلّم (hf_learning.db)
########################################
echo "---------- [3] Learning DB (hf_learning.db) ----------"

if [ -f "$LEARNING_DB" ]; then
  echo "[INFO] hf_learning.db موجود: $LEARNING_DB"
  echo "[INFO] الجداول الموجودة:"
  if sqlite3 "$LEARNING_DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" \
      | awk '{printf "  - %s\n",$1}'; then
    :
  else
    echo "[WARN] تعذّر قراءة قائمة الجداول من hf_learning.db"
  fi
  echo

  echo "[INFO] عدد الصفوف في كل جدول داخل hf_learning.db:"
  for tbl in $(sqlite3 "$LEARNING_DB" "SELECT name FROM sqlite_master WHERE type='table';"); do
    cnt=$(sqlite3 "$LEARNING_DB" "SELECT COUNT(*) FROM $tbl;" 2>/dev/null || echo "?")
    printf "  - %-25s : %s rows\n" "$tbl" "$cnt"
  done
  echo

  for cand in learning_runs sessions experiments; do
    if sqlite3 "$LEARNING_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='$cand';" \
        | grep -q "^$cand$"; then
      echo "[INFO] أول 10 صفوف من جدول $cand:"
      sqlite3 "$LEARNING_DB" "SELECT * FROM $cand ORDER BY 1 DESC LIMIT 10;"
      echo
    fi
  done
else
  echo "[WARN] لا يوجد hf_learning.db تحت $META_DIR – يبدو أن طبقة التعلّم غير مفعّلة بالكامل بعد."
fi

echo

########################################
# [4] Docker Workers / AI Containers
########################################
echo "---------- [4] Docker Workers / AI Containers ----------"

if command -v docker >/dev/null 2>&1; then
  echo "[INFO] قائمة الحاويات العاملة حاليًا (docker ps):"
  docker ps --format 'NAME={{.Names}}  IMAGE={{.Image}}  STATUS={{.Status}}' || \
    echo "[WARN] تعذّر تشغيل docker ps."
  echo

  echo "[INFO] الحاويات التي يشتبه أنها AI/ML أو Workers (اسم يحتوي ai/llm/ollama/asr/ffactory):"
  docker ps --format 'NAME={{.Names}}  IMAGE={{.Image}}  STATUS={{.Status}}' \
    | grep -Ei 'ai|llm|ollama|asr|ffactory' || \
    echo "[NOTE] لا توجد حاويات AI/ML مطابقة للأنماط المحددة أو القائمة فارغة."
else
  echo "[WARN] docker غير متوفر – لن يتم فحص العمال على مستوى الحاويات."
fi

echo
echo "====================================================="
echo " End of Workers & ML Status"
echo "====================================================="
