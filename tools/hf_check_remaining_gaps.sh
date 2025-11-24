#!/usr/bin/env bash
# HyperFFactory – Remaining Gaps Summary
# سكربت قراءة فقط:
# - لا يلمس git
# - لا يغيّر DBs (فقط يشغل سكربتات الفحص الموجودة)
# - يعطيك ملخص "إيه باقي" من الخطة + فجوات المعمارية

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"
LOG="${REPORT_DIR}/hf_remaining_gaps_${TS}.log"

log() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Remaining Gaps Summary"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "====================================================="

########################################################
# 1) البنود غير المكتملة من plan_status
########################################################
log "-----------------------------------------------------"
log "1) Plan Status – البنود غير المكتملة (🟡 / ⏭ / PLANNED / RUNNING)"
log "-----------------------------------------------------"

FOUND_PLAN_LINES=0

if [ -f "plan_status.md" ]; then
  log "[INFO] قراءة plan_status.md"
  if grep -E '🟡|⏭|PLANNED|RUNNING' plan_status.md | sed 's/^/  /' | tee -a "$LOG"; then
    FOUND_PLAN_LINES=1
  fi
fi

if [ -f "PLAN_STATUS.md" ]; then
  log "[INFO] قراءة PLAN_STATUS.md"
  if grep -E '🟡|⏭|PLANNED|RUNNING' PLAN_STATUS.md | sed 's/^/  /' | tee -a "$LOG"; then
    FOUND_PLAN_LINES=1
  fi
fi

if [ ! -f "plan_status.md" ] && [ ! -f "PLAN_STATUS.md" ]; then
  log "[WARN] لا يوجد plan_status.md أو PLAN_STATUS.md في الجذر."
elif [ "$FOUND_PLAN_LINES" -eq 0 ]; then
  log "[INFO] لا توجد أسطر غير مكتملة مطابقة للفلاتر الحالية في ملفات الخطة."
fi

########################################################
# 2) تشغيل فحص المعمارية واستخراج PLANNED / UNTRACKED
########################################################
log "-----------------------------------------------------"
log "2) Architecture Gaps – PLANNED / UNTRACKED من تقرير hf_check_plan_and_architecture"
log "-----------------------------------------------------"

if [ -x "tools/hf_check_plan_and_architecture.sh" ]; then
  log "[RUN] tools/hf_check_plan_and_architecture.sh"
  # تشغيل الفحص مع توجيه مخرجاته الكاملة للّوج (قراءة فقط)
  if tools/hf_check_plan_and_architecture.sh >>"$LOG" 2>&1; then
    log "[OK] hf_check_plan_and_architecture.sh انتهى بنجاح (قراءة فقط)"
  else
    log "[WARN] hf_check_plan_and_architecture.sh أعاد كود خروج غير صفري – راجع اللوج للتفاصيل."
  fi

  LAST_ARCH_LOG="$(ls -t reports/hf_plan_arch_audit_*.log 2>/dev/null | head -n 1 || true)"
  if [ -n "$LAST_ARCH_LOG" ]; then
    log "[INFO] استخدام آخر تقرير معماري: ${LAST_ARCH_LOG}"
    log "----- مقتطفات PLANNED / UNTRACKED / مازال PLANNED -----"
    if ! grep -E 'PLANNED-|⚠️|مازال PLANNED' "$LAST_ARCH_LOG" | sed 's/^/  /' | tee -a "$LOG"; then
      log "[INFO] لا توجد أسطر PLANNED/UNTRACKED/مازال PLANNED في التقرير الأخير."
    fi
  else
    log "[WARN] لم يتم العثور على أي ملف reports/hf_plan_arch_audit_*.log بعد تشغيل الفحص."
  fi
else
  log "[WARN] tools/hf_check_plan_and_architecture.sh غير موجود أو غير قابل للتنفيذ – تخطّي خطوة المعمارية."
fi

########################################################
# 3) Snapshot مختصر من hf_show_plan (لو موجود)
########################################################
log "-----------------------------------------------------"
log "3) Snapshot من hf_show_plan – البنود النشطة فقط"
log "-----------------------------------------------------"

if [ -x "tools/hf_show_plan.sh" ]; then
  log "[RUN] tools/hf_show_plan.sh (فلتر البنود النشطة)"
  if ! tools/hf_show_plan.sh | egrep '🟡|⏭|PLANNED|RUNNING' | sed 's/^/  /' | tee -a "$LOG"; then
    log "[INFO] لا توجد بنود نشطة مطابقة للفلاتر في مخرجات hf_show_plan.sh."
  fi
else
  log "[WARN] tools/hf_show_plan.sh غير موجود أو غير قابل للتنفيذ – تخطّي Snapshot الخطة."
fi

########################################################
# 4) ملخص نهائي
########################################################
log "-----------------------------------------------------"
log "SUMMARY"
log "-----------------------------------------------------"
log "[SUMMARY] هذا السكربت لم يغيّر أي ملفات أو DBs، فقط جمع لك:"
log "          - البنود غير المكتملة من plan_status."
log "          - PLANNED / UNTRACKED من تقرير المعمارية."
log "          - Snapshot للبنود النشطة من hf_show_plan."
log "          راجع: ${LOG}"
log "====================================================="
log "HyperFFactory – Remaining Gaps Summary finished."
log "====================================================="

exit 0
