#!/usr/bin/env bash
# HyperFFactory – Full Tree Printer (Read-Only)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

OUT="${REPORT_DIR}/hf_full_tree_${TS}.txt"

{
  echo "====================================================="
  echo "HyperFFactory – Full Tree Snapshot"
  echo "ROOT : ${ROOT}"
  echo "TIME : ${TS}"
  echo "====================================================="
  echo
  echo "${ROOT}"
  find . -mindepth 1 -print | sort
} > "$OUT"

cat "$OUT"

echo
echo "-----------------------------------------------------"
echo "تم حفظ الشجرة الكاملة في:"
echo "   $OUT"
echo "-----------------------------------------------------"
