#!/usr/bin/env bash
set -Eeuo pipefail
APP=smartfrind
LOG="/var/log/$APP/core_watchdog.log"
HOST="${SF_CORE_HOST:-127.0.0.1}"
PORT="${SF_CORE_PORT:-8213}"
for i in 1 2 3; do
  if curl -fsS "http://$HOST:$PORT/health" >/dev/null; then exit 0; fi
  sleep 3
done
echo "[$(date '+%F %T')] health failed -> restart $APP-core" >> "$LOG"
systemctl restart $APP-core.service || true
