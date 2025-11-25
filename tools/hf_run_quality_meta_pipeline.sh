#!/usr/bin/env bash
# HyperFFactory – Quality & Meta Pipeline Runner
# Stage4 (Quality/Errors/Learning) + Stage8 (Unified Health) + التقارير

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

S4="./tools/hf_stage4_quality_full.sh"
S8="./tools/hf_stage8_unified_health_full.sh"

echo "=================================================="
echo " HyperFFactory – Quality / Meta Pipeline"
echo " ROOT : $ROOT"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "=================================================="
echo

if [ ! -x "$S4" ]; then
  echo "❌ Wrapper Stage4 غير متاح: $S4"
  exit 1
fi

if [ ! -x "$S8" ]; then
  echo "❌ Wrapper Stage8 غير متاح: $S8"
  exit 1
fi

echo "▶ تشغيل Stage4 (Quality + Patterns + Dashboard)..."
"$S4"

echo
echo "▶ تشغيل Stage8 (Unified Health + Patterns + Dashboard)..."
"$S8"

echo
echo "=================================================="
echo " انتهاء Quality / Meta Pipeline"
echo "=================================================="
