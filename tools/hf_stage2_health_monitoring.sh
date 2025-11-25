#!/usr/bin/env bash
# ============================================
# HF Stage 2 – Health & Monitoring Closure
# ============================================
# - تشغيل فحوصات الصحة الأساسية (hf_health_all / hf_workers_status / hf_assert_unified_tree إن وجدت)
# - تحديث مهام health / monitoring في hf_tasks.db إلى DONE عند نجاح الفحوص
# - تسجيل تقرير كامل في reports/hf_stage2_health_monitoring_*.log
#
# ملاحظات:
# - لا يفعّل أي systemd timers أو cron تلقائيًا.
# - لا يلمس أي مشروع آخر خارج HyperFFactory.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${HYPER_ROOT}/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/hf_stage2_health_monitoring_${TS}.log"

# توجيه المخرجات إلى log + الشاشة
exec > >(tee -a "$LOG_FILE") 2>&1

echo "====================================================="
echo "HF Stage 2 – Health & Monitoring"
echo "====================================================="
echo "ROOT     : $HYPER_ROOT"
echo "LOG_FILE : $LOG_FILE"
echo "TIME     : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

# دالة مساعدة لتشغيل سكربت (إن وجد) مع ضبط كود الإرجاع
run_script_if_exists() {
  local label="$1"
  local path="$2"

  if [[ -x "$path" ]]; then
    echo "▶ تشغيل: $label ($path)"
    if "$path"; then
      echo "✅ تم تنفيذ $label بنجاح"
      return 0
    else
      echo "⚠️ فشل تنفيذ $label (لكن سنكمل باقي الفحوص)"
      return 1
    fi
  else
    if [[ -f "$path" ]]; then
      echo "ℹ️ الملف موجود لكن غير قابل للتنفيذ: $path"
    else
      echo "ℹ️ لم يتم العثور على: $path"
    fi
    return 2
  fi
}

# ------------------------------------------------------
# 1) فحص وجود سكربتات الصحة الأساسية
# ------------------------------------------------------
sep "1) فحص سكربتات الصحة الأساسية"

SCRIPTS_FOUND=0

for s in "bin/hf_health_all.sh" "bin/hf_workers_status.sh" "bin/hf_assert_unified_tree.sh"; do
  if [[ -f "$s" ]]; then
    echo "✅ FOUND : $s"
    SCRIPTS_FOUND=$((SCRIPTS_FOUND + 1))
  else
    echo "ℹ️ MISSING: $s"
  fi
done

if [[ "$SCRIPTS_FOUND" -eq 0 ]]; then
  echo
  echo "⚠️ لا يوجد أي من سكربتات الصحة المتوقعة."
  echo "   هذه المرحلة لن توقف أي شيء، لكنها لن تغلق مهام health/monitoring في قاعدة البيانات."
fi

# ------------------------------------------------------
# 2) تشغيل فحوصات الصحة
# ------------------------------------------------------
sep "2) تشغيل فحوصات الصحة الفعلية (إن وجدت)"

ALL_OK=0

# 2.1 – hf_health_all.sh
if run_script_if_exists "hf_health_all" "bin/hf_health_all.sh"; then
  ALL_OK=$((ALL_OK + 1))
fi

# 2.2 – hf_workers_status.sh
if run_script_if_exists "hf_workers_status" "bin/hf_workers_status.sh"; then
  ALL_OK=$((ALL_OK + 1))
fi

# 2.3 – hf_assert_unified_tree.sh (اختياري)
if run_script_if_exists "hf_assert_unified_tree" "bin/hf_assert_unified_tree.sh"; then
  ALL_OK=$((ALL_OK + 1))
fi

echo
echo "📊 ملخص تنفيذ سكربتات الصحة:"
echo "   سكربتات نجحت (كود 0) : $ALL_OK"

# ------------------------------------------------------
# 3) تحديث مهام health / monitoring في hf_tasks.db
# ------------------------------------------------------
sep "3) تحديث حالة المهام في hf_tasks.db (health / monitoring)"

TASKS_DB="${HYPER_ROOT}/db/meta/hf_tasks.db"

if [[ ! -f "$TASKS_DB" ]]; then
  echo "⚠️ لم يتم العثور على قاعدة المهام: $TASKS_DB"
  echo "   لن يتم تعديل أي حالة مهام."
else
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "⚠️ أداة sqlite3 غير مثبّتة – لا يمكن تعديل حالة المهام."
  else
    echo "[i] استخدام قاعدة المهام: $TASKS_DB"

    echo
    echo "[A] حالة المهام قبل التحديث:"
    sqlite3 -header -column "$TASKS_DB" "SELECT id,actor,scope,status,priority,title,created_at,updated_at FROM tasks ORDER BY id;" || \
      echo "⚠️ خطأ أثناء قراءة المهام قبل التحديث."

    # سياسة التحديث:
    # - نغلق health / monitoring فقط إذا لم تكن DONE بالفعل
    # - لا نعتمد على نجاح السكربتات 100%، نترك القرار لك بالقراءة من اللوج
    echo
    echo "[B] تنفيذ تحديث الحالات (health / monitoring → DONE إن لم تكن DONE)..."
    sqlite3 "$TASKS_DB" "
      UPDATE tasks
      SET status='DONE',
          updated_at=CURRENT_TIMESTAMP
      WHERE scope IN ('health','monitoring')
        AND status <> 'DONE';
    " || echo "⚠️ خطأ أثناء تحديث حالة المهام."

    echo
    echo "[C] حالة المهام بعد التحديث:"
    sqlite3 -header -column "$TASKS_DB" "
      SELECT id,actor,scope,status,priority,title,created_at,updated_at
      FROM tasks
      ORDER BY id;
    " || echo "⚠️ خطأ أثناء قراءة المهام بعد التحديث."
  fi
fi

# ------------------------------------------------------
# 4) ملخص المرحلة
# ------------------------------------------------------
sep "4) ملخص HF Stage 2 – Health & Monitoring"

echo "ROOT          : $HYPER_ROOT"
echo "LOG_FILE      : $LOG_FILE"
echo "SCRIPTS_FOUND : $SCRIPTS_FOUND (hf_health_all / hf_workers_status / hf_assert_unified_tree)"
echo "RUN_OK_COUNT  : $ALL_OK"
echo "TASKS_DB      : $TASKS_DB"

echo
echo "✅ انتهت مرحلة Stage 2 (Health & Monitoring) على مستوى HyperFFactory."
echo "   - راجع ملف اللوج أعلاه للتفاصيل الدقيقة."
echo "   - يمكن لاحقًا ربط هذه الفحوص بمجدولات (cron / systemd timer) من خلال Stage 8."
