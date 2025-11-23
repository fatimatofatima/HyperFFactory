#!/usr/bin/env bash
# HyperFFactory - Run Basic Data Pipeline (4 Workers)

set -euo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
RUN_LOG="$REPORT_DIR/hf_basic_pipeline_${TS}.log"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

echo "==================================================" | tee "$RUN_LOG"
echo "🚀 HYPERFFACTORY BASIC PIPELINE RUN $TS" | tee -a "$RUN_LOG"
echo "ROOT: $ROOT" | tee -a "$RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"

step() {
  local name="$1"
  local cmd="$2"
  echo "--------------------------------------------------" | tee -a "$RUN_LOG"
  echo "▶ STEP: $name" | tee -a "$RUN_LOG"
  echo "CMD : $cmd" | tee -a "$RUN_LOG"
  echo "--------------------------------------------------" | tee -a "$RUN_LOG"
  bash -c "$cmd" | tee -a "$RUN_LOG"
}

step "INGESTOR_BASIC"  "$ROOT/workers/ingestor_basic.sh"
step "PROCESSOR_BASIC" "$ROOT/workers/processor_basic.sh"
step "ANALYZER_BASIC"  "$ROOT/workers/analyzer_basic.sh"
step "REPORTER_BASIC"  "$ROOT/workers/reporter_basic.sh"

echo "==================================================" | tee -a "$RUN_LOG"
echo "✅ BASIC PIPELINE COMPLETED" | tee -a "$RUN_LOG"
echo "LOG: $RUN_LOG"
echo "==================================================" | tee -a "$RUN_LOG"
