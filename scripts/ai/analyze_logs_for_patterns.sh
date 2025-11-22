#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATASET="${ROOT_DIR}/ai/datasets/messages.jsonl"
REPORT_DIR="${ROOT_DIR}/reports/ai_eval"
mkdir -p "${REPORT_DIR}"

NOW=$(date +"%Y%m%d_%H%M%S")
OUT="${REPORT_DIR}/patterns_${NOW}.txt"

echo "HyperFFactory – Simple Patterns Report - ${NOW}" | tee "${OUT}"
echo "===============================================" | tee -a "${OUT}"

if [[ ! -f "$DATASET" ]]; then
  echo "messages.jsonl not found: $DATASET" | tee -a "${OUT}"
  exit 0
fi

TOTAL=$(wc -l < "$DATASET" || echo 0)
echo "Total lines in messages.jsonl: $TOTAL" | tee -a "${OUT}"

echo >> "${OUT}"
echo "Top keywords (very naive grep counts):" | tee -a "${OUT}"

for KW in ERROR Traceback WARNING BUG FIX TODO; do
  CNT=$(grep -i "$KW" "$DATASET" 2>/dev/null | wc -l || echo 0)
  echo "  - ${KW}: ${CNT}" | tee -a "${OUT}"
done

echo >> "${OUT}"
echo "This is فقط تحليل بدائي. لاحقًا يربط مع Python/LLM لتحليل أعمق." | tee -a "${OUT}"

