#!/usr/bin/env bash
# HyperFFactory - Smart Integration Cycle (FIXED)
# يجمع: Unified Health + Workers Status + Basic Pipeline + Unified Summary
# التنفيذ دائمًا من داخل /root/HyperFFactory
# يُفضّل تشغيله عبر hf_progress_exec لمتابعة التنفيذ في hf_ops_meta.db

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_smart_integration_cycle_${TS}.log"

OPS_DB="$ROOT/db/meta/hf_ops_meta.db"
MANAGE_DIR="$ROOT/db/meta"
Q_DB="$MANAGE_DIR/hf_quality.db"
E_DB="$MANAGE_DIR/hf_errors.db"
L_DB="$MANAGE_DIR/hf_learning.db"
T_DB="$MANAGE_DIR/hf_tasks.db"
CHANGES_DB="$MANAGE_DIR/hf_changes.db"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

print_header() {
  echo "==================================================" | tee -a "$LOG"
  echo "🚀 HYPERFFACTORY SMART INTEGRATION CYCLE ${TS}" | tee -a "$LOG"
  echo "==================================================" | tee -a "$LOG"
  log "ROOT   : $ROOT"
  log "OPS_DB : $OPS_DB"
}

run_with_progress() {
  # $1 = label, $2 = actor, $3 = scope, $4 = cmd (relative)
  local label="$1"
  local actor="$2"
  local scope="$3"
  local cmd="$4"

  echo "--------------------------------------------------" | tee -a "$LOG"
  log "▶ $label"
  echo "--------------------------------------------------" | tee -a "$LOG"

  if [[ ! -x "$ROOT/bin/hf_progress_exec.sh" ]]; then
    log "⚠️ hf_progress_exec.sh غير موجود أو غير قابل للتنفيذ – سيتم تشغيل $cmd مباشرة."
    if [[ -x "$ROOT/$cmd" ]]; then
      if "$ROOT/$cmd" | tee -a "$LOG"; then
        log "✅ $label DONE (بدون progress_exec)"
      else
        log "⚠️ $label FAILED (بدون progress_exec) – راجع اللوج أعلاه."
      fi
    else
      log "⚠️ $cmd غير موجود أو غير قابل للتنفيذ."
    fi
    return 0
  fi

  if [[ -x "$ROOT/$cmd" ]]; then
    if "$ROOT/bin/hf_progress_exec.sh" "$actor" "$scope" "$cmd" | tee -a "$LOG"; then
      log "✅ $label DONE"
    else
      log "⚠️ $label FAILED – راجع اللوج أعلاه."
    fi
  else
    log "⚠️ $cmd غير موجود أو غير قابل للتنفيذ."
  fi
}

count_files() {
  # $1 = label, $2 = dir
  local label="$1"
  local dir="$2"
  local n=0
  if [[ -d "$dir" ]]; then
    n=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | awk '{print $1}')
  fi
  printf "• %-9s: %d files (%s)\n" "$label" "$n" "$dir" | tee -a "$LOG"
}

summary_ops_meta() {
  echo "==================================================" | tee -a "$LOG"
  echo "🧠 OPS META – TASKS & PROGRESS (hf_ops_meta.db)" | tee -a "$LOG"
  echo "==================================================" | tee -a "$LOG"

  if ! command -v sqlite3 >/dev/null 2>&1 || [[ ! -f "$OPS_DB" ]]; then
    log "⚠️ sqlite3 غير متوفر أو hf_ops_meta.db غير موجود – تخطي ملخص OPS META."
    return 0
  fi

  log "== Tasks (hf_ops_meta.db) =="
  if ! sqlite3 -header -column "$OPS_DB" \
      'SELECT id,actor,status,scope,created_at,updated_at FROM tasks ORDER BY id LIMIT 20;' \
      2>>"$LOG" | tee -a "$LOG"; then
    log "⚠️ تعذّر قراءة جدول tasks في hf_ops_meta.db"
  fi

  echo "--------------------------------------------------" | tee -a "$LOG"
  log "== Last 20 Progress Events (raw) =="
  if ! sqlite3 -header -column "$OPS_DB" \
      'SELECT * FROM progress_log ORDER BY id DESC LIMIT 20;' \
      2>>"$LOG" | tee -a "$LOG"; then
    log "⚠️ تعذّر قراءة جدول progress_log في hf_ops_meta.db"
  fi
}

summary_management_dbs() {
  echo "==================================================" | tee -a "$LOG"
  echo "📊 MANAGEMENT DBS SUMMARY (db/meta)" | tee -a "$LOG"
  echo "==================================================" | tee -a "$LOG"

  local name path
  for pair in \
    "hf_quality.db $Q_DB" \
    "hf_errors.db $E_DB" \
    "hf_learning.db $L_DB" \
    "hf_tasks.db $T_DB" \
    "hf_changes.db $CHANGES_DB"
  do
    name=$(echo "$pair" | awk '{print $1}')
    path=$(echo "$pair" | awk '{print $2}')
    if [[ -f "$path" ]]; then
      local size
      size=$(stat -c%s "$path" 2>/dev/null || echo 0)
      printf "• %-12s: موجود (%s) – حجم: %s bytes\n" "$name" "$path" "$size" | tee -a "$LOG"
    else
      printf "• %-12s: غير موجود (%s)\n" "$name" "$path" | tee -a "$LOG"
    fi
  done

  if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$CHANGES_DB" ]]; then
    echo "--------------------------------------------------" | tee -a "$LOG"
    log "== Changes / Events (hf_changes.db) – Last 10 =="
    if ! sqlite3 -header -column "$CHANGES_DB" \
        'SELECT * FROM changes ORDER BY id DESC LIMIT 10;' \
        2>>"$LOG" | tee -a "$LOG"; then
      log "⚠️ تعذّر قراءة جدول changes في hf_changes.db"
    fi
  fi
}

summary_data_layers() {
  echo "==================================================" | tee -a "$LOG"
  echo "📂 DATA LAYERS SUMMARY" | tee -a "$LOG"
  echo "==================================================" | tee -a "$LOG"

  count_files "inbox"    "$ROOT/data/inbox"
  count_files "raw"      "$ROOT/data/raw"
  count_files "processed" "$ROOT/data/processed"
  count_files "semantic" "$ROOT/data/semantic"
  count_files "serving"  "$ROOT/data/serving"
}

main() {
  print_header

  # STEP 1: Unified Health
  run_with_progress \
    "STEP 1/4: Unified Health (SmartFriend + FFactory)" \
    "hyper_health" \
    "bin/hf_health_all.sh" \
    "bin/hf_health_all.sh"

  # STEP 2: Workers & Management Status
  run_with_progress \
    "STEP 2/4: Workers & Management Status" \
    "hyper_workers_status" \
    "bin/hf_workers_status.sh" \
    "bin/hf_workers_status.sh"

  # STEP 3: Basic Data Pipeline
  run_with_progress \
    "STEP 3/4: Basic Data Pipeline (ingestor → reporter)" \
    "hyper_pipeline" \
    "bin/hf_run_basic_pipeline.sh" \
    "bin/hf_run_basic_pipeline.sh"

  # STEP 4: Unified Integration Summary
  echo "--------------------------------------------------" | tee -a "$LOG"
  log "▶ STEP 4/4: Unified Integration Summary"
  echo "--------------------------------------------------" | tee -a "$LOG"

  summary_data_layers
  summary_ops_meta
  summary_management_dbs

  echo "==================================================" | tee -a "$LOG"
  echo "✅ SMART INTEGRATION CYCLE DONE" | tee -a "$LOG"
  echo "==================================================" | tee -a "$LOG"
  log "تفاصيل الدورة في: $LOG"
}

main "$@"
