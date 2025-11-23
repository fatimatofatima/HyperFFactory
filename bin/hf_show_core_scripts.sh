#!/usr/bin/env bash
set -e

ROOT="/root/HyperFFactory"
cd "$ROOT"

for f in bin/hf_assert_unified_tree.sh bin/hf_full_cycle.sh bin/hf_health_all.sh; do
  echo "=================================================="
  echo "📄 $f"
  echo "=================================================="
  if [[ -f "$f" ]]; then
    sed -n '1,200p' "$f"
  else
    echo "⚠️ الملف غير موجود"
  fi
  echo
done
