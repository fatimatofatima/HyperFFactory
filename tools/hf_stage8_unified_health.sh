#!/usr/bin/env bash
# Stage 8 – Unified Health & Monitoring Snapshot (Manual)
# قراءة + تقارير + تحديث حالة مهمة health فقط
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
REPORT_DIR="${HYPER_ROOT}/reports"
META_DIR="${HYPER_ROOT}/db/meta"
TASKS_DB="${META_DIR}/hf_tasks.db"

TS="$(date +%Y%m%d_%H%M%S)"
TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"

LOG_MAIN="${REPORT_DIR}/hf_stage8_health_${TS}.log"

mkdir -p "${REPORT_DIR}"

cd "${HYPER_ROOT}" || {
  echo "❌ لا يمكن الدخول إلى ${HYPER_ROOT}"
  exit 1
}

{
  echo "====================================================="
  echo "Stage 8 – Unified Health & Monitoring Snapshot"
  echo "====================================================="
  echo "ROOT      : ${HYPER_ROOT}"
  echo "TIME      : ${TS_HUMAN}"
  echo

  echo "-----------------------------------------------------"
  echo "1) HyperFFactory health – تشغيل bin/hf_health_all.sh إن وُجد"
  echo "-----------------------------------------------------"

  if [[ -x "bin/hf_health_all.sh" ]]; then
    START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[i] تشغيل hf_health_all.sh عند: ${START_TS}"
    START_SEC="$(date +%s)"
    if bin/hf_health_all.sh >"${REPORT_DIR}/hf_health_all_${TS}.log" 2>&1; then
      END_SEC="$(date +%s)"
      DURATION=$(( END_SEC - START_SEC ))
      echo "✅ hf_health_all.sh انتهى بنجاح خلال ${DURATION} ثانية."
      echo "   • اللوج: ${REPORT_DIR}/hf_health_all_${TS}.log"
    else
      END_SEC="$(date +%s)"
      DURATION=$(( END_SEC - START_SEC ))
      echo "⚠️ hf_health_all.sh انتهى بخطأ خلال ${DURATION} ثانية."
      echo "   • راجع: ${REPORT_DIR}/hf_health_all_${TS}.log"
    fi
  else
    echo "ℹ️ لا يوجد bin/hf_health_all.sh أو غير قابل للتنفيذ – تم التخطي."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "2) فحص المهام والمجدولات – hf_inspect_tasks_and_schedulers.sh إن وُجد"
  echo "-----------------------------------------------------"

  if [[ -x "tools/hf_inspect_tasks_and_schedulers.sh" ]]; then
    if tools/hf_inspect_tasks_and_schedulers.sh >"${REPORT_DIR}/hf_inspect_tasks_and_schedulers_${TS}.log" 2>&1; then
      echo "✅ تقرير Tasks & Schedulers جاهز:"
      echo "   • ${REPORT_DIR}/hf_inspect_tasks_and_schedulers_${TS}.log"
    else
      echo "⚠️ حدث خطأ أثناء تشغيل hf_inspect_tasks_and_schedulers.sh"
      echo "   • راجع: ${REPORT_DIR}/hf_inspect_tasks_and_schedulers_${TS}.log"
    fi
  else
    echo "ℹ️ لا يوجد tools/hf_inspect_tasks_and_schedulers.sh أو غير قابل للتنفيذ – تم التخطي."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "3) Snapshot لـ Docker (ffactory + hyper_* + web-*)"
  echo "-----------------------------------------------------"

  if command -v docker >/dev/null 2>&1; then
    if docker ps --format 'NAME={{.Names}}  IMAGE={{.Image}}  STATUS={{.Status}}  PORTS={{.Ports}}' \
         | grep -E 'ffactory|hyper_|web-' \
         > "${REPORT_DIR}/hf_docker_snapshot_${TS}.log" 2>&1; then
      echo "✅ Docker snapshot مسجل في:"
      echo "   • ${REPORT_DIR}/hf_docker_snapshot_${TS}.log"
      echo
      echo "[ملخص سريع من docker ps]:"
      sed -n '1,10p' "${REPORT_DIR}/hf_docker_snapshot_${TS}.log" || true
    else
      echo "⚠️ تعذر الحصول على docker snapshot – راجع:"
      echo "   • ${REPORT_DIR}/hf_docker_snapshot_${TS}.log"
    fi
  else
    echo "ℹ️ docker غير متوفر – تم تخطي Snapshot الحاويات."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "4) تلخيص سريع لوضع المهام من hf_tasks.db (إن وُجد)"
  echo "-----------------------------------------------------"

  if [[ -f "${TASKS_DB}" ]]; then
    echo "[i] استخدام قاعدة المهام: ${TASKS_DB}"
    echo
    sqlite3 "${TASKS_DB}" <<SQL
.headers on
.mode column
SELECT status, COUNT(*) AS cnt
FROM tasks
GROUP BY status;
SQL

    echo
    echo "[أهم المهام PLANNED الآن]:"
    sqlite3 "${TASKS_DB}" <<SQL
.headers on
.mode column
SELECT id, actor, scope, status, priority, title
FROM tasks
WHERE status='PLANNED'
ORDER BY priority ASC, id ASC
LIMIT 20;
SQL
  else
    echo "ℹ️ لا يوجد ${TASKS_DB} – لا يمكن تلخيص حالة المهام."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "5) تحديث مهمة health في hf_tasks.db إلى DONE (Capability Ready)"
  echo "-----------------------------------------------------"

  if [[ -f "${TASKS_DB}" ]]; then
    NOW_SQL="$(date '+%Y-%m-%d %H:%M:%S')"
    sqlite3 "${TASKS_DB}" <<SQL
UPDATE tasks
   SET status='DONE',
       updated_at='${NOW_SQL}'
 WHERE scope='health';
SQL

    echo "لقطة بعد التحديث (health):"
    sqlite3 "${TASKS_DB}" <<SQL
.headers on
.mode column
SELECT id, actor, scope, status, priority, title, created_at, updated_at
  FROM tasks
 WHERE scope='health';
SQL
  else
    echo "ℹ️ لا يوجد ${TASKS_DB} – لن يتم تحديث مهمة health."
  fi

  echo
  echo "====================================================="
  echo "Stage 8 – Unified Health Snapshot FINISHED"
  echo "Log file: ${LOG_MAIN}"
  echo "====================================================="
} | tee "${LOG_MAIN}"

exit 0
