#!/usr/bin/env bash
# ============================================
# HyperFFactory Dashboard CLI (قراءة فقط)
# ============================================
# يعرض:
#   - ملخص المهام (PLANNED / RUNNING / DONE) من hf_tasks.db
#   - المهام المهمة (PLANNED)
#   - مهام الـ integrations المنفذة
#   - آخر عمليات progress_log من hf_ops_meta.db
#   - آخر تقرير Reality Scan (إن وجد)
#   - Snapshot سريع للخدمات والحاويات

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS="$(date '+%Y-%m-%d %H:%M:%S %z')"
TASKS_DB="${HYPER_ROOT}/db/meta/hf_tasks.db"
OPS_META_DB="${HYPER_ROOT}/db/meta/hf_ops_meta.db"

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

need_sqlite() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "⚠️ sqlite3 غير مثبت – لن يتم عرض بيانات قواعد meta."
    return 1
  fi
  return 0
}

latest_file() {
  local pattern="$1"
  # يعيد أحدث ملف يطابق النمط أو سلسلة فارغة
  ls -1t $pattern 2>/dev/null | head -n 1 || true
}

echo "====================================================="
echo "HyperFFactory Dashboard CLI"
echo "====================================================="
echo "ROOT : $HYPER_ROOT"
echo "TIME : $TS"
echo

# ------------------------------------------------------
# 1) ملخص المهام من hf_tasks.db
# ------------------------------------------------------
sep "1) المهام (hf_tasks.db – ملخص الحالة)"

if [[ -f "$TASKS_DB" ]] && need_sqlite; then
  echo "[A] عدد المهام حسب الحالة:"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT status, COUNT(*) AS cnt
    FROM tasks
    GROUP BY status
    ORDER BY status;
  " || echo '⚠️ خطأ أثناء قراءة ملخص المهام.'

  echo
  echo "[B] أهم المهام PLANNED (أعلى أولوية، أول 20):"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT id,actor,scope,status,priority,title,created_at,updated_at
    FROM tasks
    WHERE status = 'PLANNED'
    ORDER BY priority ASC, id ASC
    LIMIT 20;
  " || echo '⚠️ خطأ أثناء قراءة المهام PLANNED.'

  echo
  echo "[C] المهام DONE الخاصة بالتكامل (integration_*):"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT id,actor,scope,status,priority,title,created_at,updated_at
    FROM tasks
    WHERE scope LIKE 'integration_%'
    ORDER BY id ASC;
  " || echo '⚠️ خطأ أثناء قراءة مهام التكامل.'
else
  echo "ℹ️ hf_tasks.db غير موجود أو sqlite3 غير متاح."
fi

# ------------------------------------------------------
# 2) آخر progress_log من hf_ops_meta.db
# ------------------------------------------------------
sep "2) عمليات HyperFFactory (hf_ops_meta.db – progress_log)"

if [[ -f "$OPS_META_DB" ]] && need_sqlite; then
  TABLE_EXISTS="$(sqlite3 "$OPS_META_DB" "
    SELECT name FROM sqlite_master
    WHERE type='table' AND name='progress_log';
  " || true)"

  if [[ -n "$TABLE_EXISTS" ]]; then
    echo "[i] آخر 15 صف من progress_log:"
    sqlite3 -header -column "$OPS_META_DB" "
      SELECT id,script_name,action,path,status,ts
      FROM progress_log
      ORDER BY id DESC
      LIMIT 15;
    " || echo '⚠️ خطأ أثناء قراءة progress_log.'
  else
    echo "ℹ️ لا يوجد جدول progress_log في hf_ops_meta.db."
  fi
else
  echo "ℹ️ hf_ops_meta.db غير موجود أو sqlite3 غير متاح."
fi

# ------------------------------------------------------
# 3) آخر تقرير Reality Scan (hf_reality_scan)
# ------------------------------------------------------
sep "3) آخر تقرير HF Reality Scan (إن وجد)"

LATEST_SUMMARY="$(latest_file '/root/hf_reality_report_summary_*.txt')"

if [[ -n "${LATEST_SUMMARY:-}" ]]; then
  echo "[i] استخدام آخر تقرير: $LATEST_SUMMARY"
  echo
  tail -n 40 "$LATEST_SUMMARY" || echo "⚠️ تعذر قراءة التقرير."
else
  echo "ℹ️ لا توجد تقارير reality مسجلة تحت /root/hf_reality_report_summary_*.txt"
fi

# ------------------------------------------------------
# 4) Snapshot سريع للخدمات الأساسية
# ------------------------------------------------------
sep "4) Snapshot – systemd (sf-core / sf-bot / ffactory / hf-workers-cycle)"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --no-pager --plain --type=service 2>/dev/null | \
    grep -E 'sf-core\.service|sf-bot\.service|ffactory\.service|hf-workers-cycle\.service' || \
    echo "ℹ️ لا توجد وحدات مطابقة أو جميعها غير معرّفة."
else
  echo "ℹ️ systemd غير متاح في هذا السياق."
fi

# ------------------------------------------------------
# 5) Snapshot سريع للحاويات (hyper*/ffactory*/web-redis-1)
# ------------------------------------------------------
sep "5) Snapshot – Docker containers (hyper*/ffactory*/web-redis-1)"

if command -v docker >/dev/null 2>&1; then
  docker ps --format 'NAME={{.Names}}  IMAGE={{.Image}}  STATUS={{.Status}}  PORTS={{.Ports}}' | \
    grep -E 'hyper_|ffactory|web-redis-1' || \
    echo "ℹ️ لا توجد حاويات hyper/ffactory/web-redis-1 قيد التشغيل أو docker لا يعرضها الآن."
else
  echo "ℹ️ docker غير مثبت أو غير متاح."
fi

echo
echo "== END HyperFFactory Dashboard @ $TS =="
