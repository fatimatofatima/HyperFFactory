#!/usr/bin/env bash
# HyperFFactory – Smart Git Staging (no delete, no data touch)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_git_smart_stage_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
    echo "[$(date +'%F %T')] $*" | tee -a "$LOG"
}

echo "=================================================="
log "HyperFFactory – Smart Git Staging (code only)"
echo "ROOT : $ROOT"
echo "LOG  : $LOG"
echo "=================================================="

cd "$ROOT"

# 1) تأكيد أن هذا مستودع Git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "❌ هذا المجلد ليس مستودع Git"
    exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD || echo 'UNKNOWN')"
log "Current branch: ${BRANCH}"

log "Initial status (مختصر):"
git status --short --branch || log "⚠️ git status فشل"
echo

# 2) قائمة المسارات الآمنة (كود/سكربت/كونفيج) التي نريد تتبّعها
SAFE_PATHS=(
  # bin – سكربتات الإدارة والحراسة
  "bin/hf_assert_unified_tree.sh"
  "bin/hf_guard.sh"
  "bin/hf_management_with_tasks.sh"
  "bin/hf_meta_dump_schemas.sh"

  # خطة التنفيذ
  "plans/HF_EXEC_PLAN.tsv"

  # Config
  "config/agents.yaml"
  "config/bots_routing.yaml"
  "config/hf_management_profile.yaml"
  "config/modules.json"
  "config/modules_enhanced.json"
  "config/worker_orchestrator.yaml"

  # SQL schemas
  "sql/init_hf_ops_meta_tasks.sql"
  "sql/meta_hf_errors_schema.sql"
  "sql/meta_hf_learning_schema.sql"
  "sql/meta_hf_ops_meta_schema.sql"
  "sql/meta_hf_quality_schema.sql"

  # Scripts / Spiders
  "scripts/spiders/hf_spider_knowledge_poc.sh"

  # Ops
  "ops/run_health.py"

  # أنظمة الأنماط والجودة والمصانع
  "patterns_system"
  "quality_system"
  "integration_hub"
  "factories"
  "temporal_memory"

  # Tools – إدارة المصنع و SmartFriend
  "tools/hf_autofix_sf_services_paths.sh"
  "tools/hf_backup_now.sh"
  "tools/hf_backup_policy_snapshot.sh"
  "tools/hf_bootstrap_advanced_infra.sh"
  "tools/hf_bootstrap_knowledge_and_patterns.sh"
  "tools/hf_bootstrap_lakehouse_and_factories.sh"
  "tools/hf_bootstrap_quality_and_training.sh"
  "tools/hf_bootstrap_unified_core.sh"
  "tools/hf_check_plan_and_architecture.sh"
  "tools/hf_check_remaining_gaps.sh"
  "tools/hf_classify_imported_github_repos.sh"
  "tools/hf_config_gaps_report.sh"
  "tools/hf_diag_smartfriend_services.sh"
  "tools/hf_find_missing_files.sh"
  "tools/hf_fix_exec_plan_headers.sh"
  "tools/hf_fix_exec_plan_tsv.sh"
  "tools/hf_fix_ops_tasks_schema.sh"
  "tools/hf_fix_python_permissions.sh"
  "tools/hf_fix_sf_pythonpath.sh"
  "tools/hf_fix_sf_services_root.sh"
  "tools/hf_fix_smartfriend_exec_paths.sh"
  "tools/hf_full_tree_print.sh"
  "tools/hf_git_add_core_batch2.sh"
  "tools/hf_git_resolve_unknown_core.sh"
  "tools/hf_git_safe_update.sh"
  "tools/hf_heavy_data_manifest.sh"
  "tools/hf_ops_fix_sf_exec.sh"
  "tools/hf_ops_fix_sf_paths2.sh"
  "tools/hf_ops_fix_sf_workdir.sh"
  "tools/hf_ops_start_suite_and_ffactory.sh"
  "tools/hf_patch_start_ffactory_core.sh"
  "tools/hf_prepare_backup_dirs.sh"
  "tools/hf_quality_report.sh"
  "tools/hf_repo_status.sh"
  "tools/hf_run_all_core_checks.sh"
  "tools/hf_sf_diag_layout.sh"
  "tools/hf_sf_fix_units_final.sh"
  "tools/hf_sf_minimal_repair.sh"
  "tools/hf_sf_smart_web_fix.sh"
  "tools/hf_sf_web_bootstrap_app.sh"
  "tools/hf_sf_web_break_root_symlink.sh"
  "tools/hf_sf_web_chdir_fix.sh"
  "tools/hf_sf_web_clean_minimal.sh"
  "tools/hf_sf_web_cleanup_fix.sh"
  "tools/hf_sf_web_create_stub_app.sh"
  "tools/hf_sf_web_diag_and_local.sh"
  "tools/hf_sf_web_fix_final.sh"
  "tools/hf_sf_web_import_fix.sh"
  "tools/hf_sf_web_memory_final_fix.sh"
  "tools/hf_sf_web_outroot_fix.sh"
  "tools/hf_sf_web_perm_fix.sh"
  "tools/hf_sf_web_py_path_fix.sh"
  "tools/hf_sf_web_reset_minimal.sh"
  "tools/hf_sf_web_root_traverse_fix.sh"
  "tools/hf_start_smartfriend_and_ffactory.sh"
  "tools/hf_start_smartfriend_and_ffactory.sh.bak.20251124_054640"
  "tools/hf_sync_plan_to_tasks.py"
  "tools/hf_sync_plan_to_tasks.sh"
  "tools/hf_tasks_overview.sh"
  "tools/hf_workers_inventory.sh"
)

# 3) مسارات نعلم مسبقًا أننا لا نريد تتبّعها في Git (تبقى على السيرفر فقط)
EXCLUDE_PREFIXES=(
  "data/"
  "db/"
  "reports/"
  "imported/"
  "opt/"
  "collected_scripts/"
)

is_excluded() {
  local p="$1"
  for prefix in "${EXCLUDE_PREFIXES[@]}"; do
    if [[ "$p" == "$prefix"* ]]; then
      return 0
    fi
  done
  return 1
}

log "Staging safe paths (لن يتم حذف أي ملف):"

for p in "${SAFE_PATHS[@]}"; do
  # لا نضيف أي شيء يقع تحت مسار مستبعد حتى لو غلطنا في القائمة
  if is_excluded "$p"; then
    log "SKIP (excluded by policy): $p"
    continue
  fi

  if [ -e "$p" ]; then
    git add "$p"
    log "STAGED: $p"
  else
    log "SKIP (not found): $p"
  fi
done

echo
log "Git status بعد عملية staging:"
git status --short --branch || log "⚠️ git status فشل"

echo
log "انتهى hf_git_smart_stage – لا يوجد أي حذف، فقط staging للكود."
echo "=================================================="
