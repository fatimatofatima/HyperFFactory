#!/usr/bin/env bash
# Promote SF-* Services to Production
set -Eeuo pipefail

if [ -f /etc/smartfriend/sf_suite.env ]; then
    source /etc/smartfriend/sf_suite.env
fi

log() { echo "[$(date '+%F %T')] $*"; }

FAILED_SERVICES=()

CORE_SERVICES=(
    "sf-memory.service"
    "sf-web.service"
    "sf-health.service"
    "sf-spider.service"
    "sf-bot.service"
    "sf-bot-programmer.service"
    "sf-telegram-audit.service"
)

log "Promoting SmartFriend Suite services..."

for service in "${CORE_SERVICES[@]}"; do
    if systemctl list-unit-files "$service" --no-legend >/dev/null 2>&1; then
        log "🔄 Enable & restart $service..."
        systemctl enable "$service" >/dev/null 2>&1 || log "⚠️ failed to enable $service"
        if systemctl restart "$service"; then
            log "✅ $service started successfully"
        else
            log "❌ Failed to start $service"
            FAILED_SERVICES+=("$service")
        fi
    else
        log "⚠️ $service not found as systemd unit - skipping"
    fi
done

if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    log "🎉 All core services promoted successfully!"
else
    log "❌ Some services failed: ${FAILED_SERVICES[*]}"
    exit 1
fi
