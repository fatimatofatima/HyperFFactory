#!/usr/bin/env bash
# HyperFFactory – Wrapper لتشغيل hf_sync_plan_to_tasks.py مع لوج في reports/

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPORT_DIR}/hf_sync_plan_to_tasks_${TS}.log"

echo "====================================================="
echo "HyperFFactory – Sync Plan → hf_ops_meta.tasks"
echo "ROOT : ${ROOT}"
echo "TIME : ${TS}"
echo "LOG  : ${LOG}"
echo "====================================================="
echo

# تشغيل السكربت مع حفظ اللوج
python3 tools/hf_sync_plan_to_tasks.py | tee "${LOG}"

echo
echo "-----------------------------------------------------"
echo "[INFO] Log file:"
echo "  ${LOG}"
echo "-----------------------------------------------------"
