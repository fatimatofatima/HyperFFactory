#!/usr/bin/env bash
# HyperFFactory – Resolve UNKNOWN set (v1)
# - يطبّق قرار الأعمال على UNKNOWN:
#   * TRACK_CORE  → git add
#   * RUNTIME_ONLY → تقرير فقط (بدون git add)
#   * MANUAL_REVIEW → تقرير فقط (بدون git add)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="reports/hf_git_resolve_unknown_${TS}.log"

mkdir -p reports

log() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $*" | tee -a "$REPORT"
}

log "=================================================="
log "🧩 HyperFFactory – Resolve UNKNOWN Set (v1)"
log "ROOT : $ROOT"
log "TIME : $TS"
log "REPORT: $REPORT"
log "=================================================="

# -------- 1) عناصر TRACK_CORE (ندخلها الريبو) --------
TRACK_CORE=(
  "activate_full_brain.sh"
  "brain_monitor.sh"
  "docs/UNIFIED_FACTORY_LOGIN.md"
  "docs/scripts_catalog.md"
  "fix_identity_schema.sql"
  "fix_knowledge_schema.sql"
  "fix_knowledge_schema_correct.sql"
  "fix_meta_columns.sql"
  "hyper_bootstrap_enhanced.sh"
  "hyper_bootstrap_local.sh"
  "hyper_bootstrap_production.sh"
  "hyper_check_short.sh"
  "hyper_factory/__init__.py"
  "hyper_factory/api/__init__.py"
  "hyper_factory/api/main.py"
  "hyper_final_check.sh"
  "hyper_repo_manager.sh"
  "hyper_server_check.sh"
)

log "## 1) TRACK_CORE – git add لعناصر المصنع الأساسية"
for p in "${TRACK_CORE[@]}"; do
  if [[ -e "$p" ]]; then
    git add "$p"
    log "[ADD] $p"
  else
    log "[MISS] $p (غير موجود حاليًا، لم يتم git add)"
  fi
done

# -------- 2) عناصر RUNTIME_ONLY (تظل خارج git) --------
RUNTIME_ONLY=(
  "data/"
  "db_inventory_20251122_034302.tsv"
  "hf_backups_report_20251123_051136.txt"
  "plan_status.md.bak_20251123_161340"
)

log ""
log "## 2) RUNTIME_ONLY – تبقى خارج git (لا git add في هذا السكربت)"
for p in "${RUNTIME_ONLY[@]}"; do
  if [[ -e "$p" ]]; then
    log "[RUNTIME] $p (موجود – يفضّل تركه خارج الريبو / أو إضافته لاحقًا إلى .gitignore يدويًا إن رغبت)"
  else
    log "[RUNTIME-MISS] $p (غير موجود حاليًا)"
  fi
done

# -------- 3) عناصر MANUAL_REVIEW --------
MANUAL_REVIEW=(
  "collected_scripts/sh_scripts/"
  "ط؟"  # placeholder: الأسماء العربية قد تظهر مشفّرة في التقارير؛ نكتبها حرفيًا يدويًا إذا لزم.
  # ملاحظة: الأسماء العربية الأربعة تُترك للمراجعة اليدوية.
)

log ""
log "## 3) MANUAL_REVIEW – تُترك للقرار اليدوي (لا تغيير تلقائي)"
log "⚠️ العناصر التالية لم تُلمس (لا git add):"
log "   - collected_scripts/sh_scripts/"
log "   - الأسماء العربية الأربعة كما ظهرت في تقرير UNKNOWN (تحتاج قرارك: نقلها إلى docs/ أو حذفها يدويًا من الشجرة)"

log ""
log "✅ تم تنفيذ قرارات TRACK_CORE. راجع git status ثم قرر بخصوص RUNTIME/MANUAL."
log "=================================================="
