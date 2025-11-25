#!/usr/bin/env bash
# ============================================
# Stage 6 – HyperFFactory Quality System
# ============================================
# الهدف:
#   - تعريف مؤشرات جودة أساسية في hf_quality.db (إن لم تكن موجودة).
#   - أخذ Snapshot من hf_tasks.db وإدخاله في quality_runs.
#   - عدم تعديل سكيمة الجداول الحالية نهائيًا.
#
# يعتمد على:
#   - db/meta/hf_quality.db
#   - db/meta/hf_tasks.db (للإحصائيات)
#
# ناتج:
#   - صفوف جديدة في quality_runs لمعاملات:
#       * tasks_total
#       * tasks_done
#       * tasks_planned
#       * tasks_done_ratio
# ============================================

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
META_DIR="${HYPER_ROOT}/db/meta"
QUALITY_DB="${META_DIR}/hf_quality.db"
TASKS_DB="${META_DIR}/hf_tasks.db"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"
TS_SQL="$(date '+%Y-%m-%d %H:%M:%S')"

echo "====================================================="
echo "Stage 6 – HyperFFactory Quality System (hf_quality.db)"
echo "====================================================="
echo "ROOT      : ${HYPER_ROOT}"
echo "TIMESTAMP : ${TS_HUMAN}"
echo

# --------------------------------------------------
# 1) تأكيد وجود قاعدة الجودة وتفعيل WAL فقط
# --------------------------------------------------
if [ ! -f "${QUALITY_DB}" ]; then
  echo "❌ لم يتم العثور على ${QUALITY_DB} – تأكد أن Stage 4 تم تنفيذه."
  exit 1
fi

sqlite3 "${QUALITY_DB}" "PRAGMA journal_mode=WAL;" >/dev/null

# --------------------------------------------------
# 2) تعريف مؤشرات الجودة الأساسية (quality_metrics)
# --------------------------------------------------
echo "-----------------------------------------------------"
echo "2) تعريف مؤشرات الجودة الأساسية في quality_metrics"
echo "-----------------------------------------------------"

sqlite3 "${QUALITY_DB}" <<'SQL'
INSERT OR IGNORE INTO quality_metrics (code, name, description, unit, active)
VALUES
  ('tasks_total',       'إجمالي المهام',          'إجمالي عدد المهام في hf_tasks.db',          'count', 1),
  ('tasks_done',        'المهام المكتملة',        'عدد المهام بحالة DONE في hf_tasks.db',       'count', 1),
  ('tasks_planned',     'المهام المخططة',         'عدد المهام بحالة PLANNED في hf_tasks.db',    'count', 1),
  ('tasks_done_ratio',  'نسبة الإنجاز (%)',       'نسبة المهام المكتملة من إجمالي المهام',      'percent', 1);
SQL

echo "[i] تم ضمان وجود مؤشرات الجودة الأساسية (INSERT OR IGNORE فقط)."
echo

# --------------------------------------------------
# 3) قراءة Snapshot من hf_tasks.db
# --------------------------------------------------
echo "-----------------------------------------------------"
echo "3) جمع مؤشرات الجودة من hf_tasks.db"
echo "-----------------------------------------------------"

if [ ! -f "${TASKS_DB}" ]; then
  echo "ℹ️ لا يوجد ${TASKS_DB} – لن يتم إدخال Snapshot للمهام."
  exit 0
fi

TOTAL_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks;")
DONE_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks WHERE status='DONE';")
PLANNED_TASKS=$(sqlite3 "${TASKS_DB}" "SELECT COUNT(*) FROM tasks WHERE status='PLANNED';")

if [ "${TOTAL_TASKS}" -gt 0 ]; then
  # حساب النسبة (0–100) بدقة بسيطة
  DONE_RATIO=$(python3 - <<PY
total = ${TOTAL_TASKS}
done = ${DONE_TASKS}
ratio = (done * 100.0 / total) if total > 0 else 0.0
print(f"{ratio:.2f}")
PY
)
else
  DONE_RATIO="0.00"
fi

echo "[i] TOTAL_TASKS   = ${TOTAL_TASKS}"
echo "[i] DONE_TASKS    = ${DONE_TASKS}"
echo "[i] PLANNED_TASKS = ${PLANNED_TASKS}"
echo "[i] DONE_RATIO    = ${DONE_RATIO}%"
echo

# --------------------------------------------------
# 4) إدخال Snapshot في quality_runs
# --------------------------------------------------
echo "-----------------------------------------------------"
echo "4) إدخال Snapshot في جدول quality_runs"
echo "-----------------------------------------------------"

# نتحقق أن الجدول موجود (بدون لمس السكيمة)
HAS_QRUNS=$(sqlite3 "${QUALITY_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='quality_runs';")
if [ -z "${HAS_QRUNS}" ]; then
  echo "❌ جدول quality_runs غير موجود في hf_quality.db – تأكد من Stage 4."
  exit 1
fi

sqlite3 "${QUALITY_DB}" "INSERT INTO quality_runs (metric_code, ts, value, status, details)
VALUES (
  'tasks_total',
  '${TS_SQL}',
  ${TOTAL_TASKS},
  'OK',
  'Snapshot من hf_tasks.db عند ${TS_HUMAN}'
);"

sqlite3 "${QUALITY_DB}" "INSERT INTO quality_runs (metric_code, ts, value, status, details)
VALUES (
  'tasks_done',
  '${TS_SQL}',
  ${DONE_TASKS},
  'OK',
  'Snapshot من hf_tasks.db عند ${TS_HUMAN}'
);"

sqlite3 "${QUALITY_DB}" "INSERT INTO quality_runs (metric_code, ts, value, status, details)
VALUES (
  'tasks_planned',
  '${TS_SQL}',
  ${PLANNED_TASKS},
  'OK',
  'Snapshot من hf_tasks.db عند ${TS_HUMAN}'
);"

sqlite3 "${QUALITY_DB}" "INSERT INTO quality_runs (metric_code, ts, value, status, details)
VALUES (
  'tasks_done_ratio',
  '${TS_SQL}',
  ${DONE_RATIO},
  'OK',
  'Snapshot من hf_tasks.db عند ${TS_HUMAN} (نسبة مئوية)'
);"

echo "[i] تم تسجيل Snapshot للجودة في quality_runs."
echo

# --------------------------------------------------
# 5) عرض آخر Snapshot سريعًا
# --------------------------------------------------
echo "-----------------------------------------------------"
echo "5) آخر صفوف quality_runs لهذه المؤشرات"
echo "-----------------------------------------------------"

sqlite3 "${QUALITY_DB}" <<'SQL'
.headers on
.mode column
SELECT id, metric_code, ts, value, status
FROM quality_runs
WHERE metric_code IN ('tasks_total','tasks_done','tasks_planned','tasks_done_ratio')
ORDER BY id DESC
LIMIT 20;
SQL

echo
echo "✅ Stage 6 مكتمل: تم تعريف المؤشرات وتسجيل Snapshot أولي للجودة."
echo "====================================================="
