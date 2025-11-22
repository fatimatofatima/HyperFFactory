#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

echo "🧠 تهيئة قاعدة الهوية من قواعد smartfrind القديمة..."
python3 "$ROOT/tools/hyper_identity_seed_from_legacy.py"

echo "📈 إحصائية سريعة:"
sqlite3 /opt/hyper-factory/var/db/identity/identity.db '
  SELECT "entities_count" AS label, COUNT(*) AS value FROM entities
  UNION ALL
  SELECT "migrations_count", COUNT(*) FROM identity_migrations;
'
