#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hf_guard_cycle.log"

TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "==== HF GUARD CYCLE ${TS} ====" >> "$LOG_FILE"

# 1) فحص سياسة الشجرة الموحّدة
if [[ -x bin/hf_assert_unified_tree.sh ]]; then
    echo "[INFO] running hf_assert_unified_tree.sh" >> "$LOG_FILE"
    if ! bin/hf_assert_unified_tree.sh >> "$LOG_FILE" 2>&1; then
        echo "[WARN] hf_assert_unified_tree.sh returned non-zero" >> "$LOG_FILE"
    fi
else
    echo "[WARN] bin/hf_assert_unified_tree.sh not found or not executable" >> "$LOG_FILE"
fi

# 2) فحص الصحة الموحد
if [[ -x bin/hf_health_all.sh ]]; then
    echo "[INFO] running hf_health_all.sh" >> "$LOG_FILE"
    if ! bin/hf_health_all.sh >> "$LOG_FILE" 2>&1; then
        echo "[WARN] hf_health_all.sh returned non-zero" >> "$LOG_FILE"
    fi
else
    echo "[WARN] bin/hf_health_all.sh not found or not executable" >> "$LOG_FILE"
fi

echo >> "$LOG_FILE"
