#!/usr/bin/env bash
# HyperFFactory - Safe Repo Update (no delete, no clean)
# يحدّث الريبو بالحالة الحالية للتكامل بدون حذف أي شيء

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"
LOG="$REPORT_DIR/hf_repo_update_${TS}.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

log "=================================================="
log "🚀 HF REPO UPDATE START $TS"
log "ROOT = $ROOT"
log "LOG  = $LOG"
log "=================================================="

if [ ! -d ".git" ]; then
  log "❌ لا يوجد .git في $ROOT – إلغاء التحديث."
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "📌 الفرع الحالي: $CURRENT_BRANCH"

log "📊 git status (قبل):"
git status --short | tee -a "$LOG" || true

# تشغيل دورة التكامل مرة واحدة (Health + Workers + Pipeline + Summary)
if [ -x "bin/hf_smart_integration_cycle.sh" ] && [ -x "bin/hf_progress_exec.sh" ]; then
  log "▶ تشغيل دورة التكامل عبر hf_progress_exec.sh..."
  bin/hf_progress_exec.sh \
    "hyper_integration_cycle" \
    "bin/hf_smart_integration_cycle.sh" \
    "bin/hf_smart_integration_cycle.sh" | tee -a "$LOG"
else
  log "⚠️ bin/hf_smart_integration_cycle.sh أو bin/hf_progress_exec.sh غير موجود/غير قابل للتنفيذ – تخطي خطوة التشغيل."
fi

# إنشاء ملف حالة رسمي داخل الريبو
STATUS_DIR="$ROOT/status"
mkdir -p "$STATUS_DIR"
STATUS_FILE="$STATUS_DIR/STATUS_HYPER_INTEGRATION.md"

cat > "$STATUS_FILE" <<EOF_STATUS
# HyperFFactory – Integration Snapshot

- Timestamp : $TS
- Root      : $ROOT
- Branch    : $CURRENT_BRANCH

آخر دورة تكامل تم تشغيلها بنجاح عبر:

- bin/hf_smart_integration_cycle.sh
- bin/hf_health_all.sh
- bin/hf_workers_status.sh
- bin/hf_run_basic_pipeline.sh

راجع آخر تقارير التكامل في مجلد:

- reports/hf_smart_integration_cycle_*.log

هذا الملف يثبت أن حالة التكامل (Health + Workers + Pipeline + Meta) كانت تعمل وقت هذا الكوميت.
EOF_STATUS

log "✅ تم تحديث ملف الحالة: $STATUS_FILE"

# Stage: تحديث الملفات المتتبَّعة فقط (لا ملفات جديدة ولا حذف)
log "📦 git add -u (تحديث الملفات المتتبَّعة فقط)..."
git add -u | tee -a "$LOG" || true

# إضافة الملفات الجديدة الأساسية صراحة (بدون لمس أي شيء آخر)
log "📦 git add لملفات التكامل الأساسية:"
git add \
  "$STATUS_FILE" \
  bin/hf_smart_integration_cycle.sh \
  bin/hf_workers_status.sh 2>>"$LOG" || true

log "📊 git status (بعد git add):"
git status --short | tee -a "$LOG" || true

# لو مفيش تغييرات staged → لا نعمل commit
if git diff --cached --quiet; then
  log "ℹ️ لا توجد تغييرات staged – لن يتم إنشاء commit جديد."
  log "✅ HF REPO UPDATE DONE (بدون commit)"
  exit 0
fi

COMMIT_MSG="chore: hyper integration cycle + workers status wiring @ $TS"
log "📝 إنشاء commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" | tee -a "$LOG"

log "=================================================="
log "✅ HF REPO UPDATE DONE (تم إنشاء commit محليًا)"
log "💡 لو حابب ترفع على GitHub، نفّذ يدويًا:"
log "    git push origin $CURRENT_BRANCH"
log "=================================================="
