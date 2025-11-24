#!/usr/bin/env bash
# HyperFFactory – Add CORE batch 2 to git (management + tools + workers + sql)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="reports"
LOG="$LOG_DIR/hf_git_add_core_batch2_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $*" | tee -a "$LOG"
}

log "=================================================="
log "🧩 HyperFFactory – Add CORE Batch 2 to git"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "=================================================="

CORE_PATHS=(
  "scripts/hf_build_management_and_push.sh"
  "scripts/hf_management_smart_run.sh"
  "scripts/hf_setup_management_and_push.sh"
  "scripts/hf_sync_status_and_plan.sh"
  "scripts/hf_update_plan_and_repo.sh"
  "scripts/run_hyper_api.sh"
  "scripts/setup_auto_updater.sh"

  "self_learning_brain.py"
  "simple_brain.py"

  "sql"
  "structure.txt"

  "tools/check_hf_backups.sh"
  "tools/execute_safe_cleanup.sh"
  "tools/final_verification.sh"
  "tools/hf_backups_quick_report.sh"
  "tools/hf_cleanup_unpacked.sh"
  "tools/hf_enforce_unified_root.sh"
  "tools/hf_find_smartfriend_unified_db.sh"
  "tools/hf_flatten_src_to_root.sh"
  "tools/hf_hide_default_motd.sh"
  "tools/hf_index_scripts.sh"
  "tools/hf_inspect_and_fix_src.sh"
  "tools/hf_quarantine_archives.sh"
  "tools/hf_root_cleanup.sh"
  "tools/hf_scan_brain_memory_quality.sh"
  "tools/hf_scan_health_fix_reports.sh"
  "tools/hf_scan_repo_health_fix_report.sh"
  "tools/hf_set_login_banner.sh"
  "tools/hf_show_plan.sh"
  "tools/hf_update_readme_real.sh"
  "tools/hyper_check_all_dbs.sh"
  "tools/hyper_list_db_users.sh"

  "workers"
)

log "## 1) إضافة عناصر CORE الجديدة (git add)"
for p in "${CORE_PATHS[@]}"; do
  if [[ -e "$p" ]]; then
    git add "$p"
    log "[ADD] $p"
  else
    log "[MISS] $p (غير موجود حاليًا – لم يتم git add)"
  fi
done

log ""
log "## 2) عناصر Manual Review (لم تُلمس في هذا السكربت)"
log "   - Arabic paths كما ظهرت في git status:"
log "     * \"\\\\330\\\\243\\\\331\\\\212\""
log "     * \"\\\\330\\\\247\\\\331\\\\204\\\\330\\\\252\\\\331\\\\206\\\\331\\\\201\\\\331\\\\212\\\\330\\\\260\""
log "     * \"\\\\330\\\\254\\\\331\\\\205\\\\331\\\\212\\\\330\\\\271\""
log "     * \"\\\\331\\\\205\\\\331\\\\207\\\\331\\\\205:\""
log ""
log "✅ انتهى hf_git_add_core_batch2.sh – راجع git status قبل أي commit."
log "=================================================="
