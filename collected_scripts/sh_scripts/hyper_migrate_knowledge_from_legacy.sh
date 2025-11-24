#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
PY="$ROOT/tools/hyper_migrate_knowledge_from_legacy.py"

echo "🧠 تشغيل هجرة المعرفة من قواعد legacy إلى knowledge_main"
echo "   سكربت: $PY"
echo "--------------------------------------------------"

if [[ ! -f "$PY" ]]; then
  echo "❌ سكربت Python غير موجود: $PY"
  exit 1
fi

python3 "$PY"
