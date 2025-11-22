#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

TS="$(date +%Y%m%d_%H%M%S)"
OUT="docs/project_tree_${TS}.txt"

echo "HyperFFactory Project Tree - $(date)" > "$OUT"
echo "Root: $(pwd)" >> "$OUT"
echo >> "$OUT"

# هيكل كامل مع استثناء بعض المسارات الثقيلة
find . \
  -path './.git' -prune -o \
  -path './.venv' -prune -o \
  -path './venv' -prune -o \
  -path './node_modules' -prune -o \
  -path './__pycache__' -prune -o \
  -print | sort >> "$OUT"

echo "✅ تم حفظ الهيكل في: $OUT"
echo
echo "📄 معاينة أول 150 سطر:"
echo "----------------------------------------"
head -n 150 "$OUT"
echo "----------------------------------------"
echo "ℹ️ لعرض الملف كاملًا:"
echo "    less $OUT"
