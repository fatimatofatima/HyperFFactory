#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
OUT="$REPORT_DIR/sf_suite_status_${TS}.txt"

log(){ echo "[$(date '+%F %T')] $*"; }

KEY_SF_UNITS=(
  sf-core.service
  sf-unified.service
  sf-memory.service
  sf-web.service
  sf-spider.service
  sf-health.service
  sf-bot.service
  sf-bot-model.service
  sf-bot-programmer.service
  sf-telegram.service
  sf-telegram-audit.service
  sf-smartfriend.service
  sf-smartfrind.service
  sf-smartfactory.service
)

{
  echo "============================================================"
  echo " SmartFriend Suite – Complete Status Snapshot"
  echo " Timestamp : $(date '+%F %T')"
  echo " Hostname  : $(hostname)"
  echo "============================================================"
  echo

  echo "### 1) System summary"
  echo
  echo "---- uptime ----"
  uptime || true
  echo
  echo "---- free -h ----"
  free -h || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 2) Key SmartFriend Suite services (sf-*)"
  echo
  for u in "${KEY_SF_UNITS[@]}"; do
    echo "[$u]"
    systemctl list-unit-files "$u" --no-legend 2>/dev/null || echo "  (no unit-file)"
    systemctl status "$u" --no-pager -n 5 2>/dev/null || echo "  (no status)"
    echo
  done
  echo "------------------------------------------------------------"
  echo

  echo "### 3) All sf-* runtimes (list-units)"
  echo
  systemctl list-units 'sf-*' --no-pager --plain 2>/dev/null || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 4) Listening ports (SmartFriend / SmartFrind / Suite)"
  echo
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>/dev/null | \
      grep -E '(:80 |:80$|:8080|:8210|:8211|:8212|:8213|:8214|:8220|:8383|:8390)' \
      || echo "No matching ports found."
  else
    echo "ss command not found – skipping ports section."
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 5) Nginx health-check (/nginx-health)"
  echo
  if command -v curl >/dev/null 2>&1; then
    curl -sS -m 3 http://127.0.0.1/nginx-health || echo "nginx-health check failed or not configured."
  else
    echo "curl not found – skipping nginx health."
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "End of SmartFriend Suite – Status Snapshot"
  echo "============================================================"
} | tee "$OUT"

log "تم إنشاء تقرير الحالة:"
log "  $OUT"
