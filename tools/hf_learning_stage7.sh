#!/usr/bin/env bash
# Stage 7 – HyperFFactory Learning System Bootstrap
# إنشاء hf_learning.db + تسجيل أول Snapshot لإشارات التعلّم
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
META_DIR="${HYPER_ROOT}/db/meta"
LEARNING_DB="${META_DIR}/hf_learning.db"
TASKS_DB="${META_DIR}/hf_tasks.db"
OPS_DB="${META_DIR}/hf_ops_meta.db"

SMART_SUITE_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
SMARTFRIND_DIR="/var/lib/smartfrind"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"
TS_SQL="$(date '+%Y-%m-%d %H:%M:%S')"
SNAP_LABEL="stage7_initial"

echo "====================================================="
echo "Stage 7 – HyperFFactory Learning System (hf_learning.db)"
echo "====================================================="
echo "ROOT      : ${HYPER_ROOT}"
echo "TIMESTAMP : ${TS_HUMAN}"
echo

# 0) التأكد من المسار
cd "${HYPER_ROOT}" || {
  echo "❌ لا يمكن الدخول إلى ${HYPER_ROOT}"
  exit 1
}

mkdir -p "${META_DIR}"

echo "-----------------------------------------------------"
echo "1) إنشاء/تحديث سكيمة قاعدة التعلّم hf_learning.db"
echo "-----------------------------------------------------"

sqlite3 "${LEARNING_DB}" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS learning_events (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    ts             TEXT NOT NULL,
    snapshot_label TEXT NOT NULL,
    source_system  TEXT NOT NULL,
    event_type     TEXT NOT NULL,
    ref_db         TEXT NOT NULL,
    ref_table      TEXT NOT NULL,
    metric         TEXT NOT NULL,
    value          REAL NOT NULL,
    unit           TEXT DEFAULT '',
    confidence     REAL DEFAULT 1.0,
    details        TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_learning_events_ts
    ON learning_events(ts);

CREATE INDEX IF NOT EXISTS idx_learning_events_source_type
    ON learning_events(source_system, event_type);
SQL

echo "✅ سكيمة hf_learning.db جاهزة."
echo

# دالة مساعدة لإدخال Event واحدة
insert_event() {
  local ts="$1"
  local snap="$2"
  local source_system="$3"
  local event_type="$4"
  local ref_db="$5"
  local ref_table="$6"
  local metric="$7"
  local value="$8"
  local unit="$9"
  local confidence="${10}"
  local details="${11}"

  sqlite3 "${LEARNING_DB}" <<SQL
INSERT INTO learning_events
(ts, snapshot_label, source_system, event_type, ref_db, ref_table, metric, value, unit, confidence, details)
VALUES
('${ts}', '${snap}', '${source_system}', '${event_type}', '${ref_db}', '${ref_table}', '${metric}', ${value}, '${unit}', ${confidence}, '${details}');
SQL
}

# ----------------------------------------------------
# 2) إشارات تعلّم من مهام HyperFFactory (hf_tasks.db)
# ----------------------------------------------------
echo "-----------------------------------------------------"
echo "2) إشارات تعلّم من hf_tasks.db (وضع المهام الحالي)"
echo "-----------------------------------------------------"

if [[ -f "${TASKS_DB}" ]]; then
  echo "[i] استخدام قاعدة المهام: ${TASKS_DB}"

  TOTAL_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
  DONE_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks WHERE status='DONE';" 2>/dev/null || echo "0")
  PLANNED_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks WHERE status='PLANNED';" 2>/dev/null || echo "0")

  echo "  - TOTAL_TASKS   = ${TOTAL_TASKS}"
  echo "  - DONE_TASKS    = ${DONE_TASKS}"
  echo "  - PLANNED_TASKS = ${PLANNED_TASKS}"

  insert_event "${TS_SQL}" "${SNAP_LABEL}" "hyperffactory" "tasks_baseline" "hf_tasks.db" "tasks" "total_tasks"   "${TOTAL_TASKS}"  "count" 1.0 "Baseline لعدد كل المهام المسجلة."
  insert_event "${TS_SQL}" "${SNAP_LABEL}" "hyperffactory" "tasks_baseline" "hf_tasks.db" "tasks" "done_tasks"    "${DONE_TASKS}"   "count" 1.0 "Baseline لعدد المهام المكتملة."
  insert_event "${TS_SQL}" "${SNAP_LABEL}" "hyperffactory" "tasks_baseline" "hf_tasks.db" "tasks" "planned_tasks" "${PLANNED_TASKS}" "count" 1.0 "Baseline لعدد المهام المخططة."

else
  echo "ℹ️ لا يوجد ${TASKS_DB} – يتم تخطي إشارات المهام."
fi

echo

# ----------------------------------------------------
# 3) إشارات تعلّم من progress_log (hf_ops_meta.db) – إن وُجد
# ----------------------------------------------------
echo "-----------------------------------------------------"
echo "3) إشارات تعلّم من hf_ops_meta.db (progress_log)"
echo "-----------------------------------------------------"

if [[ -f "${OPS_DB}" ]]; then
  echo "[i] استخدام قاعدة العمليات: ${OPS_DB}"

  HAS_TABLE=$(sqlite3 "${OPS_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='progress_log';" 2>/dev/null || echo "")
  if [[ -n "${HAS_TABLE}" ]]; then
    TOTAL_LOGS=$(sqlite3 "${OPS_DB}" "SELECT COUNT(*) FROM progress_log;" 2>/dev/null || echo "0")
    DONE_LOGS=$(sqlite3 "${OPS_DB}" "SELECT COUNT(*) FROM progress_log WHERE status='DONE';" 2>/dev/null || echo "0")

    echo "  - TOTAL_LOGS = ${TOTAL_LOGS}"
    echo "  - DONE_LOGS  = ${DONE_LOGS}"

    insert_event "${TS_SQL}" "${SNAP_LABEL}" "hyperffactory" "ops_baseline" "hf_ops_meta.db" "progress_log" "total_logs" "${TOTAL_LOGS}" "rows" 1.0 "Baseline لعدد سجلات التشغيل."
    insert_event "${TS_SQL}" "${SNAP_LABEL}" "hyperffactory" "ops_baseline" "hf_ops_meta.db" "progress_log" "done_logs"  "${DONE_LOGS}"  "rows" 1.0 "Baseline لعدد السجلات الناجحة (DONE)."
  else
    echo "ℹ️ لا يوجد جدول progress_log في ${OPS_DB} – يتم التخطي."
  fi
else
  echo "ℹ️ لا يوجد ${OPS_DB} – يتم تخطي إشارات العمليات."
fi

echo

# ----------------------------------------------------
# 4) إشارات تعلّم من SmartFriend Unified DB
# ----------------------------------------------------
echo "-----------------------------------------------------"
echo "4) إشارات تعلّم من smartfriend_unified.db (معرفة/ذاكرة)"
echo "-----------------------------------------------------"

if [[ -f "${SMART_SUITE_DB}" ]]; then
  echo "[i] استخدام قاعدة SmartFriend Suite: ${SMART_SUITE_DB}"

  # نحاول التقاط جداول أساسية لو موجودة
  for T in "kb_fts_data" "knowledge_base" "ai_memory"; do
    HAS_T=$(sqlite3 "${SMART_SUITE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${T}';" 2>/dev/null || echo "")
    if [[ -n "${HAS_T}" ]]; then
      ROWS=$(sqlite3 "${SMART_SUITE_DB}" "SELECT COUNT(*) FROM ${T};" 2>/dev/null || echo "0")
      echo "  - ${T} : ${ROWS} rows"
      insert_event "${TS_SQL}" "${SNAP_LABEL}" "smartfriend_suite" "knowledge_baseline" "smartfriend_unified.db" "${T}" "rows_count" "${ROWS}" "rows" 1.0 "Baseline لحجم جدول ${T} في السيوت."
    fi
  done

else
  echo "ℹ️ لا يوجد ${SMART_SUITE_DB} – يتم تخطي SmartFriend Unified."
fi

echo

# ----------------------------------------------------
# 5) إشارات تعلّم من قواعد smartfrind القديمة (إن وجدت)
# ----------------------------------------------------
echo "-----------------------------------------------------"
echo "5) إشارات تعلّم من /var/lib/smartfrind/*.db"
echo "-----------------------------------------------------"

if [[ -d "${SMARTFRIND_DIR}" ]]; then
  for DB in "${SMARTFRIND_DIR}"/*.db; do
    [[ -f "${DB}" ]] || continue
    BASENAME="$(basename "${DB}")"
    echo "[i] فحص DB: ${DB}"

    # نحاول التقاط ai_memory و knowledge_base لو موجودين
    for T in "ai_memory" "knowledge_base"; do
      HAS_T=$(sqlite3 "${DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${T}';" 2>/dev/null || echo "")
      if [[ -n "${HAS_T}" ]]; then
        ROWS=$(sqlite3 "${DB}" "SELECT COUNT(*) FROM ${T};" 2>/dev/null || echo "0")
        echo "    - ${T} : ${ROWS} rows"
        insert_event "${TS_SQL}" "${SNAP_LABEL}" "smartfrind_legacy" "memory_baseline" "${BASENAME}" "${T}" "rows_count" "${ROWS}" "rows" 0.9 "Baseline لذاكرة/معرفة قديمة في smartfrind."
      fi
    done
  done
else
  echo "ℹ️ لا يوجد مجلد ${SMARTFRIND_DIR} – يتم تخطي smartfrind legacy."
fi

echo

# ----------------------------------------------------
# 6) تحديث مهمة learning_system في hf_tasks.db إلى DONE
# ----------------------------------------------------
echo "-----------------------------------------------------"
echo "6) تحديث مهمة learning_system في hf_tasks.db إلى DONE"
echo "-----------------------------------------------------"

if [[ -f "${TASKS_DB}" ]]; then
  sqlite3 "${TASKS_DB}" <<SQL
UPDATE tasks
   SET status='DONE',
       updated_at='${TS_SQL}'
 WHERE scope='learning_system';
SQL

  echo "لقطة بعد التحديث (learning_system):"
  sqlite3 "${TASKS_DB}" <<SQL
.headers on
.mode column
SELECT id, actor, scope, status, priority, title, created_at, updated_at
  FROM tasks
 WHERE scope='learning_system';
SQL
else
  echo "ℹ️ لا يوجد ${TASKS_DB} – لن يتم تحديث حالة المهمة."
fi

echo
echo "====================================================="
echo "Stage 7 – COMPLETED (hf_learning.db + initial snapshot)"
echo "====================================================="
