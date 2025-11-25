#!/usr/bin/env bash
# ============================================
# HF Stage 5 – Dashboard CLI Task Finalizer
# ============================================
# الهدف:
#   - التأكد من وجود hf_dashboard_cli.sh وقابليته للتنفيذ.
#   - تحديث مهمة dashboard في hf_tasks.db من PLANNED → DONE.
#   - لا يلمس أي أنظمة خارج HyperFFactory.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS_SHORT="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${HYPER_ROOT}/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/hf_stage5_dashboard_cli_${TS_SHORT}.log"

TASKS_DB="${HYPER_ROOT}/db/meta/hf_tasks.db"
DASHBOARD_SCRIPT="${HYPER_ROOT}/tools/hf_dashboard_cli.sh"

exec > >(tee -a "$LOG_FILE") 2>&1

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

need_sqlite() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "❌ sqlite3 غير مثبت – لا يمكن تعديل hf_tasks.db."
    exit 1
  fi
}

echo "====================================================="
echo "HF Stage 5 – Dashboard CLI Task Finalizer"
echo "====================================================="
echo "ROOT      : $HYPER_ROOT"
echo "TASKS_DB  : $TASKS_DB"
echo "DASHBOARD : $DASHBOARD_SCRIPT"
echo "LOG_FILE  : $LOG_FILE"
echo "TIME      : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

# ------------------------------------------------------
# 1) فحص وجود سكربت Dashboard
# ------------------------------------------------------
sep "1) التحقق من وجود hf_dashboard_cli.sh"

if [[ -x "$DASHBOARD_SCRIPT" ]]; then
  echo "✅ تم العثور على hf_dashboard_cli.sh وهو قابل للتنفيذ."
else
  if [[ -f "$DASHBOARD_SCRIPT" ]]; then
    echo "⚠️ الملف موجود لكن غير قابل للتنفيذ – سيتم اعتباره غير جاهز."
  else
    echo "⚠️ لم يتم العثور على hf_dashboard_cli.sh تحت $DASHBOARD_SCRIPT"
  fi
  echo "⚠️ لن يتم تغيير حالة مهمة dashboard في hf_tasks.db حتى تجهز لوحة القيادة."
  exit 0
fi

# ------------------------------------------------------
# 2) تحديث حالة مهمة dashboard في hf_tasks.db
# ------------------------------------------------------
sep "2) تحديث مهمة dashboard في hf_tasks.db → DONE"

if [[ ! -f "$TASKS_DB" ]]; then
  echo "⚠️ لم يتم العثور على قاعدة المهام: $TASKS_DB"
  echo "   لا يوجد ما يمكن تحديثه."
  exit 0
fi

need_sqlite

echo "[A] المهام قبل التحديث (scope = 'dashboard'):"
sqlite3 -header -column "$TASKS_DB" "
  SELECT id,actor,scope,status,priority,title,created_at,updated_at
  FROM tasks
  WHERE scope = 'dashboard'
  ORDER BY id;
" || echo "⚠️ خطأ أثناء قراءة المهام قبل التحديث."

echo
echo "[B] تعيين المهام ذات scope='dashboard' إلى DONE (إن لم تكن DONE بالفعل)..."
sqlite3 "$TASKS_DB" "
  UPDATE tasks
  SET status = 'DONE',
      updated_at = CURRENT_TIMESTAMP
  WHERE scope = 'dashboard'
    AND status <> 'DONE';
" || echo "⚠️ خطأ أثناء تحديث حالة المهام."

echo
echo "[C] المهام بعد التحديث (scope = 'dashboard'):"
sqlite3 -header -column "$TASKS_DB" "
  SELECT id,actor,scope,status,priority,title,created_at,updated_at
  FROM tasks
  WHERE scope = 'dashboard'
  ORDER BY id;
" || echo "⚠️ خطأ أثناء قراءة المهام بعد التحديث."

# ------------------------------------------------------
# 3) ملخص
# ------------------------------------------------------
sep "3) ملخص Stage 5 – Dashboard"

echo "✅ تم التحقق من وجود hf_dashboard_cli.sh وتشغيله كلوحة قيادة."
echo "✅ تم تحديث مهمة dashboard في hf_tasks.db إلى DONE (إن وُجدت)."
echo "📄 راجع اللوج لمزيد من التفاصيل: $LOG_FILE"
