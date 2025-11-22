#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
IDENTITY_DB="/opt/hyper-factory/var/db/identity/identity.db"
TASK_DB="/opt/hyper-factory/var/db/tasks/tasks.db"

echo "🧠 تشغيل Seed للعمال (هوية + tasks)"
echo "   IDENTITY_DB = $IDENTITY_DB"
echo "   TASK_DB     = $TASK_DB"
echo "--------------------------------------------------"

if [[ ! -f "$IDENTITY_DB" ]]; then
  echo "❌ identity.db غير موجود. تأكد أن طبقة الهوية مهيأة."
  exit 1
fi

if [[ ! -f "$TASK_DB" ]]; then
  echo "❌ tasks.db غير موجود. شغّل hyper_init_brain_and_knowledge.sh أو v2 أولاً."
  exit 1
fi

if ! sqlite3 "$TASK_DB" "SELECT name FROM sqlite_master WHERE name='workers';" | grep -q 'workers'; then
  echo "❌ جدول workers غير موجود في tasks.db. شغّل hyper_init_workers_tables.sh أولاً."
  exit 1
fi

python3 "$ROOT/tools/hyper_seed_workers_from_services.py"

echo
echo "== معاينة سريعة للعمال في tasks.workers =="
sqlite3 "$TASK_DB" "SELECT id, worker_code, entity_id, host, status, max_concurrent_jobs, current_jobs FROM workers;"

