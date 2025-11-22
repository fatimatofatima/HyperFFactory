#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
PY="$ROOT/tools/hyper_migrate_identity_from_legacy.py"

echo "🧠 تشغيل هجرة الهوية من القواعد القديمة إلى identity.entities"
echo "   سكربت: $PY"
echo "--------------------------------------------------"

if [[ ! -f "$PY" ]]; then
  echo "❌ سكربت Python غير موجود: $PY"
  exit 1
fi

python3 "$PY"
