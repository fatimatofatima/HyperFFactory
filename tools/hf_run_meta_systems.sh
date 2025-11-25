#!/usr/bin/env bash
# HyperFFactory – Meta Systems Orchestrator (using wrappers, not raw stages)

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

TOOLS_DIR="$ROOT/tools"
WORKERS_DIR="$ROOT/HyperFFactory/workers"
NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

run_step() {
  local label="$1"; shift
  local bin="$1"
  echo "--------------------------------------------------"
  echo "▶ $label"
  echo "--------------------------------------------------"

  if [ ! -x "$bin" ]; then
    echo "⚠️ تخطي: الملف غير موجود أو غير قابل للتنفيذ: $bin"
    echo
    return 0
  fi

  shift || true

  if "$bin" "$@"; then
    echo "✅ $label – OK"
  else
    local rc=$?
    echo "❌ $label – فشل برمز $rc (متابعة بقية الخطوات)"
  fi

  echo
}

echo "=================================================="
echo " HyperFFactory – Meta Systems Orchestrator"
echo " ROOT : $ROOT"
echo " TIME : $NOW"
echo "=================================================="
echo

# 1) Stage4 – Quality / Errors / Learning (Wrapper)
run_step "Stage4 – Quality / Errors / Learning (wrapper)" \
  "$TOOLS_DIR/hf_stage4_quality_full.sh"

# 2) Stage8 – Unified Health (Wrapper)
run_step "Stage8 – Unified Health (wrapper)" \
  "$TOOLS_DIR/hf_stage8_unified_health_full.sh"

# 3) Quality / Meta Dashboard (رؤية موحدة)
run_step "Quality / Meta Dashboard (CLI)" \
  "$TOOLS_DIR/hf_quality_dashboard_cli.sh"

# 4) Patterns Engine CLI (من hf_learning → hf_patterns)
run_step "Patterns Engine (hf_learning → hf_patterns)" \
  "$TOOLS_DIR/hf_patterns_engine_cli.sh"

# 5) Basic Pipeline Workers عبر الـ wrappers الرسمية (إن وُجدت)
if [ -d "$WORKERS_DIR" ]; then
  echo "--------------------------------------------------"
  echo "▶ Basic Pipeline Workers via HyperFFactory/workers"
  echo "--------------------------------------------------"

  run_step "Basic Worker – ingestor_basic" \
    "$WORKERS_DIR/ingestor_basic.sh"

  run_step "Basic Worker – processor_basic" \
    "$WORKERS_DIR/processor_basic.sh"

  run_step "Basic Worker – analyzer_basic" \
    "$WORKERS_DIR/analyzer_basic.sh"
else
  echo "⚠️ تخطي workers: المجلد غير موجود: $WORKERS_DIR"
  echo
fi

echo "=================================================="
echo " انتهاء تشغيل Meta Systems Orchestrator"
echo "=================================================="
