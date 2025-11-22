#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

log "Booting SmartFriend Brain + FFactory support stack"

# قائمة الخدمات الأساسية للعقل
SF_SERVICES=(
  sf-memory.service
  sf-unified.service
  sf-health.service
  sf-bot.service
)

# قائمة خدمات المصنع الداعم
FF_SERVICES=(
  ff-healthd.service
  ff-board.service
)

log "Reloading systemd daemon..."
systemctl daemon-reload

boot_service() {
  local svc="$1"

  if systemctl list-unit-files | grep -q "^${svc}"; then
    log "Enabling ${svc}..."
    systemctl enable "${svc}" || true

    log "Starting ${svc}..."
    systemctl start "${svc}" || true

    log "Status (${svc}):"
    systemctl --no-pager --full status "${svc}" | sed 's/^/  /' || true
  else
    log "Service ${svc} not found in unit files, skipping"
  fi
}

log "=== Booting SmartFriend Brain services (Identity/Memory/Knowledge/Learning) ==="
for svc in "${SF_SERVICES[@]}"; do
  boot_service "$svc"
done

log "=== Booting FFactory support services (Health/Board) ==="
for svc in "${FF_SERVICES[@]}"; do
  boot_service "$svc"
done

log "Final summary (filtered):"
systemctl --no-pager --type=service | egrep 'sf-|ff-' || true

log "Done."
