#!/usr/bin/env bash
# HyperFFactory – stage core code/config/scripts (no runtime)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

echo "=================================================="
echo "[hf_git_stage_core] Staging HyperFFactory core files"
echo "ROOT: $ROOT"
echo "=================================================="

# تأكد من وجود بلوك .gitignore قبل أي شيء (اختياري لكن أفضل)
if [ -x tools/hf_git_prepare_ignore.sh ]; then
    echo "[hf_git_stage_core] Ensuring runtime ignore block exists..."
    tools/hf_git_prepare_ignore.sh || true
fi

# ملفات/مجلدات الكود الأساسية
TARGETS=(
  "bin"
  "config"
  "tools"
  "scripts"
  "sql"
  "factories"
  "integration_hub"
  "patterns_system"
  "quality_system"
  "temporal_memory"
  "collected_scripts"
  "plan_status.md"
  "plans/HF_EXEC_PLAN.tsv"
)

for t in "${TARGETS[@]}"; do
    if [ -e "$t" ]; then
        echo "[hf_git_stage_core] git add $t"
        git add "$t"
    else
        echo "[hf_git_stage_core] skip (not found): $t"
    fi
done

echo "--------------------------------------------------"
echo "[hf_git_stage_core] git status --short:"
git status --short
echo "=================================================="
echo "[hf_git_stage_core] Done (staged core code; runtime still local only)"
echo "=================================================="
