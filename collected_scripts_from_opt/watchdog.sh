#!/usr/bin/env bash
set -Eeuo pipefail
APP=smartfrind
URL="http://127.0.0.1:8210/ping"
LOG="/var/log/smartfrind/watchdog.log"
MAX_RETRIES=4
RETRY_DELAY=5
log(){ echo "[$(date '+%F %T')]" "$@" >> "$LOG"; }

if ! systemctl is-active --quiet ${APP}-gateway.service; then
  log "gateway inactive -> start"
  systemctl start ${APP}-gateway.service || true
  sleep 8
fi

ok=0
for i in $(seq 1 $MAX_RETRIES); do
  if curl -fsS --max-time 4 "$URL" >/dev/null 2>&1; then ok=1; break; fi
  sleep "$RETRY_DELAY"
done

if [ "$ok" -ne 1 ]; then
  log "ping failed -> restarting ${APP}-gateway.service"
  journalctl -u ${APP}-gateway.service -n 40 --no-pager >> "$LOG" 2>&1 || true
  systemctl restart ${APP}-gateway.service || true
fi
