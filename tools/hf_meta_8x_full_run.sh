#!/usr/bin/env bash
# HyperFFactory – Meta Systems 8.x Full Run
# - يشغّل دورة أنظمة:
#   8.1 Tasks
#   8.2 Quality
#   8.3 Experience & Training
#   8.4 Errors & Incidents
#   + Snapshot & Dashboard
#
# السياسة:
# - READ/WRITE فقط على db/meta/*
# - لا يلمس /opt/ffactory ولا /opt/smartfriend-suite إلا عبر السكربتات القائمة (health/quality...)
# - يحترم "عدم حذف أي بيانات" (عمليات INSERT/UPDATE فقط).

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

cd "$ROOT"

ts() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

log() {
  local level="$1"; shift
  echo "$(ts) [META-8x] [$level] $*"
}

run_step() {
  local id="$1"; shift
  local cmd="$*"
  log INFO "STEP[$id] start: $cmd"
  if eval "$cmd"; then
    log INFO "STEP[$id] done ✅"
  else
    local rc=$?
    log WARN "STEP[$id] FAILED (exit=$rc) – استمر في باقي الخطوات."
    return $rc
  fi
}

log INFO "ROOT     = $ROOT"
log INFO "META_DIR = $META_DIR"
log INFO "بدء دورة أنظمة 8.x (Tasks / Quality / Experience / Errors)..."

# ----------------------------------------------------
# 8.1 Tasks – تأمين مهام الـ meta systems
# ----------------------------------------------------
if [[ -x tools/hf_tasks_seed_db_manager.sh ]]; then
  run_step "8.1a-seed-db-manager" "bash tools/hf_tasks_seed_db_manager.sh"
else
  log WARN "hf_tasks_seed_db_manager.sh غير موجود – تخطي مرحلة Seed مهام مدير قواعد البيانات."
fi

if [[ -x tools/hf_tasks_seed_experience.sh ]]; then
  run_step "8.1b-seed-experience" "bash tools/hf_tasks_seed_experience.sh"
else
  log WARN "hf_tasks_seed_experience.sh غير موجود – تخطي Seed مهام نظام الخبرة."
fi

if [[ -x tools/hf_tasks_sync_plan.sh ]]; then
  run_step "8.1c-sync-plan" "bash tools/hf_tasks_sync_plan.sh"
else
  log WARN "hf_tasks_sync_plan.sh غير موجود – لن يتم مزامنة plan_status.md مع hf_tasks.db."
fi

# ----------------------------------------------------
# 8.2 Quality – تحويل health/تقارير لجودة hf_quality.db
# ----------------------------------------------------
if [[ -x tools/hf_quality_stage6_fixed.sh ]]; then
  run_step "8.2a-quality-stage6" "bash tools/hf_quality_stage6_fixed.sh"
elif [[ -x tools/hf_quality_stage6.sh ]]; then
  run_step "8.2a-quality-stage6" "bash tools/hf_quality_stage6.sh"
else
  log WARN "hf_quality_stage6*.sh غير موجود – تخطي مرحلة Quality ingestion."
fi

# ----------------------------------------------------
# 8.4 Errors & Incidents – تغذية مهام الحوادث من الجودة/الأخطاء
# ----------------------------------------------------
if [[ -x tools/hf_tasks_feedback_from_quality_and_errors.sh ]]; then
  run_step "8.4a-feedback-tasks" "bash tools/hf_tasks_feedback_from_quality_and_errors.sh"
else
  log WARN "hf_tasks_feedback_from_quality_and_errors.sh غير موجود – لن تُضاف مهام حوادث تلقائية."
fi

# ----------------------------------------------------
# 8.3 Experience & Training – حساب خبرة الـ Actors
# ----------------------------------------------------
if [[ -x tools/hf_experience_init.sh ]]; then
  run_step "8.3a-experience-init" "bash tools/hf_experience_init.sh"
else
  log WARN "hf_experience_init.sh غير موجود – لن يتم تحديث hf_actor_stats."
fi

if [[ -x tools/hf_experience_report.sh ]]; then
  run_step "8.3b-experience-report" "bash tools/hf_experience_report.sh | head -80"
else
  log WARN "hf_experience_report.sh غير موجود – لا يوجد تقرير خبرة نصي."
fi

# ----------------------------------------------------
# Snapshot + Dashboard – ربط كل شيء في صورة واحدة
# ----------------------------------------------------
if [[ -x tools/hf_status_snapshot.sh ]]; then
  run_step "SNAPSHOT" "bash tools/hf_status_snapshot.sh"
else
  log WARN "hf_status_snapshot.sh غير موجود – لا يوجد Snapshot موحّد."
fi

if [[ -x tools/hf_dashboard_cli.sh ]]; then
  run_step "DASHBOARD" "bash tools/hf_dashboard_cli.sh | head -120"
else
  log WARN "hf_dashboard_cli.sh غير موجود – لا يوجد Dashboard CLI."
fi

log INFO "انتهاء دورة أنظمة 8.x."
