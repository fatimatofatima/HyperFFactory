#!/usr/bin/env bash
# HyperFFactory – Guard Script
# - حارس سريع يشغّل فحوصات السياسة الأساسية (الآن: tree policy)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
BIN_DIR="$ROOT/bin"

TS="$(date +%Y%m%d_%H%M%S)"

echo "=================================================="
echo "HyperFFactory – Guard"
echo "Time : $TS"
echo "Root : $ROOT"
echo "=================================================="

if "$BIN_DIR/hf_assert_unified_tree.sh"; then
  echo "✅ Tree Policy OK"
else
  echo "❌ Tree Policy Violations – راجع reports/hf_assert_unified_tree_*.log"
fi
