#!/usr/bin/env bash
# HyperFFactory – Main Guard
# - يشغّل حراسة موحّدة على:
#   * شجرة الهيكل الموحد (hf_assert_unified_tree.sh)
#   * نظام المهام (seed + sync + feedback)
#   * تقارير الثغرات (hf_truth_check_gaps.sh) إن وجد
#   * تدقيق قواعد البيانات (hf_db_audit.sh) إن وجد
#
# أوضاع:
#   بدون وسائط       → فحص فقط (no fix على الشجرة)
#   --fix-tree        → السماح لـ hf_assert_unified_tree بعمل --fix
#
# السياسة:
#   - لا يعمل خارج /root/HyperFFactory
#   - لا يلمس /opt/smartfriend-suite ولا /opt/ffactory
#   - يسجّل كل خطوة في logs/hf_guard_*.log + stdout

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
ROOT="${ROOT%/}"

if [[ -z "$ROOT" || "$ROOT" == "/" ]]; then
  echo "❌ ROOT غير صالح لـ hf_guard: '$ROOT'" >&2
  exit 1
fi

cd "$ROOT"

LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

RUN_ID="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/hf_guard_${RUN_ID}.log"

GUARD_MODE="CHECK_ONLY"
ASSERT_FIX_FLAG=""

for arg in "$@"; do
  case "$arg" in
    --fix-tree)
      GUARD_MODE="FIX_TREE"
      ASSERT_FIX_FLAG="--fix"
      ;;
    *)
      echo "⚠️ وسيط غير معروف لـ hf_guard: $arg (تم تجاهله)" | tee -a "$LOG_FILE" >&2
      ;;
  esac
done

log() {
  local lvl="$1"; shift
  local msg="$*"
  local ts
  ts="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  printf '%s [%s] %s\n' "$ts" "$lvl" "$msg" | tee -a "$LOG_FILE"
}

log "INFO" "=================================================="
log "INFO" " HyperFFactory – Main Guard"
log "INFO" " ROOT : $ROOT"
log "INFO" " MODE : $GUARD_MODE"
log "INFO" " LOG  : $LOG_FILE"
log "INFO" "=================================================="

#----------------------------------------
# STEP 0 – فحص أساسي للأدوات
#----------------------------------------
for tool in sqlite3 docker curl systemctl; do
  if command -v "$tool" >/dev/null 2>&1; then
    log "INFO" "CHECK TOOL: $tool → موجود"
  else
    log "WARN" "CHECK TOOL: $tool → مفقود (سيتم تخطّي أي خطوة تعتمد عليه)"
  fi
done

#----------------------------------------
# STEP 1 – حراسة الهيكل: hf_assert_unified_tree.sh
#----------------------------------------
if [[ -x "$ROOT/bin/hf_assert_unified_tree.sh" ]]; then
  log "INFO" "STEP 1: حراسة الشجرة (hf_assert_unified_tree.sh ${ASSERT_FIX_FLAG}) ..."
  if "$ROOT/bin/hf_assert_unified_tree.sh" ${ASSERT_FIX_FLAG} >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 1 OK: سياسة الهيكل تم فحصها (mode=$GUARD_MODE)."
  else
    log "WARN" "STEP 1 WARN: hf_assert_unified_tree.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 1 SKIP: bin/hf_assert_unified_tree.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 2 – Seed مهام مدير قواعد بيانات الميتا
#----------------------------------------
if [[ -x "$ROOT/tools/hf_tasks_seed_db_manager.sh" ]]; then
  log "INFO" "STEP 2: Seed مهام hf_db_manager في hf_tasks.db ..."
  if "$ROOT/tools/hf_tasks_seed_db_manager.sh" >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 2 OK: تم حقن مهام hf_db_manager."
  else
    log "WARN" "STEP 2 WARN: hf_tasks_seed_db_manager.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 2 SKIP: tools/hf_tasks_seed_db_manager.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 3 – Sync tasks مع plan_status.md
#----------------------------------------
if [[ -x "$ROOT/tools/hf_tasks_sync_plan.sh" ]]; then
  log "INFO" "STEP 3: Sync المهام من plan_status.md إلى hf_tasks.db ..."
  if "$ROOT/tools/hf_tasks_sync_plan.sh" >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 3 OK: تم مزامنة المهام مع plan_status.md."
  else
    log "WARN" "STEP 3 WARN: hf_tasks_sync_plan.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 3 SKIP: tools/hf_tasks_sync_plan.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 4 – Feedback من الأخطاء والجودة → مهام
#----------------------------------------
if [[ -x "$ROOT/tools/hf_tasks_feedback_from_quality_and_errors.sh" ]]; then
  log "INFO" "STEP 4: Feedback من hf_errors.db + hf_quality.db إلى hf_tasks.db ..."
  if "$ROOT/tools/hf_tasks_feedback_from_quality_and_errors.sh" >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 4 OK: تم تغذية المهام من الأخطاء والجودة (بدون كسر UNIQUE)."
  else
    log "WARN" "STEP 4 WARN: hf_tasks_feedback_from_quality_and_errors.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 4 SKIP: tools/hf_tasks_feedback_from_quality_and_errors.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 5 – Truth Check (Gaps) إن وُجد
#----------------------------------------
if [[ -x "/root/hf_truth_check_gaps.sh" ]]; then
  log "INFO" "STEP 5: Truth Check (hf_truth_check_gaps.sh) – READ-ONLY ..."
  if "/root/hf_truth_check_gaps.sh" >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 5 OK: تقرير الثغرات تم توليده (راجع اللوج والتقرير)."
  else
    log "WARN" "STEP 5 WARN: hf_truth_check_gaps.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 5 SKIP: /root/hf_truth_check_gaps.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 6 – DB Audit إن وُجد (فحص فقط)
#----------------------------------------
if [[ -x "$ROOT/tools/hf_db_audit.sh" ]]; then
  log "INFO" "STEP 6: DB Audit (hf_db_audit.sh) – READ-ONLY ..."
  if "$ROOT/tools/hf_db_audit.sh" >>"$LOG_FILE" 2>&1; then
    log "INFO" "STEP 6 OK: تدقيق قواعد بيانات HyperFFactory تم (فحص فقط)."
  else
    log "WARN" "STEP 6 WARN: hf_db_audit.sh انتهى بتحذير/خطأ – راجع اللوج."
  fi
else
  log "WARN" "STEP 6 SKIP: tools/hf_db_audit.sh غير موجود أو غير قابل للتنفيذ."
fi

#----------------------------------------
# STEP 7 – خلاصة سريعة من hf_tasks.db
#----------------------------------------
if [[ -f "$ROOT/db/meta/hf_tasks.db" ]]; then
  TOTAL_TASKS="$(sqlite3 "$ROOT/db/meta/hf_tasks.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo 0)"
  log "INFO" "SUMMARY: إجمالي المهام داخل hf_tasks.db بعد الحراسة: ${TOTAL_TASKS}"

  log "INFO" "TOP PLANNED TASKS:"
  sqlite3 -header -column "$ROOT/db/meta/hf_tasks.db" "
    SELECT id, actor, scope, status, priority, substr(title,1,60) AS title
    FROM tasks
    WHERE status='PLANNED'
    ORDER BY priority DESC, id DESC
    LIMIT 15;
  " 2>/dev/null | tee -a "$LOG_FILE" || true
else
  log "WARN" "SUMMARY SKIP: hf_tasks.db غير موجود."
fi

log "INFO" "=================================================="
log "INFO" " نهاية HF Main Guard – راجع اللوج: $LOG_FILE"
log "INFO" "=================================================="
