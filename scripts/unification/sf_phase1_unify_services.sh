#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

log "Phase 1 - unify systemd services (SmartFriend / FFactory)"

# 1) Disable broken SmartFrind core/api
for svc in smartfrind-core.service smartfrind-api.service; do
  if systemctl list-unit-files | grep -q "^${svc}"; then
    log "Stopping $svc (if active)..."
    systemctl stop "$svc" 2>/dev/null || true
    log "Disabling $svc..."
    systemctl disable "$svc" 2>/dev/null || true
  else
    log "Service $svc not present, skipping"
  fi
done

# 2) Put ffactory.service in safe state (disable only, don't mask)
if systemctl list-unit-files | grep -q "^ffactory.service"; then
  log "Stopping ffactory.service (if active)..."
  systemctl stop ffactory.service 2>/dev/null || true
  log "Disabling ffactory.service..."
  systemctl disable ffactory.service 2>/dev/null || true
else
  log "ffactory.service not present, skipping"
fi

# 3) Reload daemon
log "Reloading systemd daemon..."
systemctl daemon-reload

# 4) Show key service states (SmartFriend + FFactory health)
log "Final service snapshot:"
systemctl --no-pager --full status \
  sf-health.service \
  sf-memory.service \
  sf-unified.service \
  sf-bot.service \
  ff-healthd.service \
  ff-board.service 2>&1 || true

log "Phase 1 completed."
