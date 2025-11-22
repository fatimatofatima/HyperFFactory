#!/bin/bash
set -Eeuo pipefail
APP=smartfrind
LOG_FILE="/var/log/smartfrind/rolling-update.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "Starting rolling update for $APP..."

# 1) إيقاف watchdog مؤقتاً
log "Stopping watchdog timer..."
systemctl stop ${APP}-watchdog.timer

# 2) تحديث Core أولاً
log "Updating Core service..."
systemctl restart ${APP}-core.service
sleep 5

if curl -fs http://127.0.0.1:8213/health >/dev/null; then
    log "Core update successful"
else
    log "Core update FAILED - aborting"
    systemctl start ${APP}-watchdog.timer
    exit 1
fi

# 3) تحديث Gateway
log "Updating Gateway service..."
systemctl restart ${APP}-gateway.service
sleep 5

API_KEY=$(grep SMARTFRIND_API_KEY /etc/smartfrind/config.env 2>/dev/null | cut -d= -f2 || true)
if [ -n "$API_KEY" ] && curl -fs -H "X-API-Key: $API_KEY" http://127.0.0.1:8210/health >/dev/null; then
    log "Gateway update successful"
else
    log "Gateway update FAILED - attempting rollback"
    systemctl restart ${APP}-gateway.service
    sleep 3
fi

# 4) إعادة تشغيل watchdog
log "Restarting watchdog timer..."
systemctl start ${APP}-watchdog.timer

log "Rolling update completed successfully"
