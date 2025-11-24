#!/usr/bin/env bash
# HyperFFactory – Safe Git update (no deletions)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_git_safe_update_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "====================================================="
log "HyperFFactory – Safe Git update (no deletions)"
log "ROOT  : $ROOT"
log "TIME  : $TS"
log "LOG   : $LOG"
log "====================================================="

cd "$ROOT"

# تحديد الفرع الحالي
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
log "BRANCH: $CURRENT_BRANCH"

log "1) git remote -v"
git remote -v 2>&1 | tee -a "$LOG"

log "2) git status (قبل)"
git status --short 2>&1 | tee -a "$LOG" || true

log "3) git pull --rebase origin ${CURRENT_BRANCH}"
if git pull --rebase origin "${CURRENT_BRANCH}" 2>&1 | tee -a "$LOG"; then
  log "✓ pull --rebase done"
else
  log "⚠️ git pull --rebase failed (conflict?) – fix conflicts then rerun"
  exit 1
fi

log "4) Stage ONLY new/modified files (no deletions) – git add ."
# ملاحظة: git add . لا يقوم بسترجة الحذف، فقط ملفات جديدة/معدلة
git add . 2>&1 | tee -a "$LOG"

log "5) Commit if something is staged"
if git diff --cached --quiet; then
  log "ℹ️ لا توجد تغييرات مُهيّأة – لن يتم إنشاء commit"
else
  MSG="HyperFFactory: safe sync from server ${TS}"
  log "✓ committing: $MSG"
  git commit -m "$MSG" 2>&1 | tee -a "$LOG"
fi

log "6) Push to origin/${CURRENT_BRANCH} (إن وجد شيء جديد)"
if git diff --quiet HEAD; then
  log "ℹ️ لا توجد تغييرات جديدة لدفعها إلى الريموت"
else
  git push origin "${CURRENT_BRANCH}" 2>&1 | tee -a "$LOG"
fi

log "7) git status (بعد)"
git status --short 2>&1 | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_git_safe_update"
log "Report: $LOG"
log "====================================================="
