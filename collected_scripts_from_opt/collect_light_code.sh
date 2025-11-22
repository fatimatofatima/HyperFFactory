#!/usr/bin/env bash
set -Eeuo pipefail
OUT="/root/code_snapshot_$(date +%F_%H%M).tar.zst"
cd /opt/smartfriend-suite
tar --exclude='**/venv' --exclude='**/node_modules' \
    --exclude='**/__pycache__' --exclude='**/*.bin' \
    --exclude='**/*.pt' --exclude='**/*.onnx' \
    --exclude='**/*.db' --exclude='**/*.log' \
    -caf "$OUT" $(git ls-files 2>/dev/null || find . -type f \( -name '*.py' -o -name '*.sh' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.toml' \) -size -128k)
echo "$OUT"
