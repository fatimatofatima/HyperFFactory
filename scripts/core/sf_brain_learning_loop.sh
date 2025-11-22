#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
UNIFY="$APP_ROOT/scripts/unify_memory.py"

echo "[$(date '+%F %T')] [sf_brain_learning_loop] بدء حلقة التعلم المستمر..."
if [ ! -x "$PY" ] || [ ! -f "$UNIFY" ]; then
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] تحذير: Python أو unify_memory.py غير موجودين – خروج."
  exit 0
fi

trap 'echo "[$(date "+%F %T")] [sf_brain_learning_loop] تم استلام إشارة إيقاف، إنهاء..."; exit 0' INT TERM

while true; do
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] تشغيل unify_memory..."
  "$PY" "$UNIFY" || echo "[$(date '+%F %T')] [sf_brain_learning_loop] تحذير: unify_memory.py فشل."
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] نوم 900 ثانية..."
  sleep 900
done
