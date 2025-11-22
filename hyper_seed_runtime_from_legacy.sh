#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
META_DB="$ROOT/meta/hyper_meta.db"
RUNTIME_ROOT="/opt/hyper-factory/var/db"
IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"
MEMORY_DB="$RUNTIME_ROOT/memory/memory_core_2025.db"

echo "🧠 Seed من الميتا إلى Runtime (قراءة فقط من قواعد قديمة)"
echo "  META_DB     = $META_DB"
echo "  IDENTITY_DB = $IDENTITY_DB"
echo "  MEMORY_DB   = $MEMORY_DB"
echo "--------------------------------------------------"

if [[ ! -f "$META_DB" ]]; then
  echo "❌ META DB غير موجود: $META_DB"
  exit 1
fi

if [[ ! -f "$IDENTITY_DB" ]]; then
  echo "❌ identity.db غير موجود: $IDENTITY_DB"
  echo "↪ تأكد من تشغيل hyper_init_runtime_dbs.sh أولاً"
  exit 1
fi

if [[ ! -f "$MEMORY_DB" ]]; then
  echo "❌ memory_core_2025.db غير موجود: $MEMORY_DB"
  echo "↪ تأكد من تشغيل hyper_init_runtime_dbs.sh أولاً"
  exit 1
fi

python3 "$ROOT/tools/hyper_seed_runtime_from_legacy.py" \
  --meta "$META_DB" \
  --identity "$IDENTITY_DB" \
  --memory "$MEMORY_DB"
