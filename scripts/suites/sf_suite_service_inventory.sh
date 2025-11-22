#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
REPORT_FILE="$REPORT_DIR/sf_suite_service_inventory_${TS}.txt"

mkdir -p "$REPORT_DIR"

log() { echo "[$(date '+%F %T')] $*"; }

{
  echo "============================================================"
  echo " SmartFriend Suite – Service Inventory Report"
  echo " Timestamp : $(date '+%F %T')"
  echo " Hostname  : $(hostname)"
  echo "============================================================"
  echo

  echo "### 1) Core directories"
  echo
  for d in \
    "/opt/smartfriend-suite" \
    "/opt/smartfriend-suite/var" \
    "/opt/smartfriend-suite/var/db" \
    "/opt/smartfriend-suite/var/knowledge" \
    "/opt/smartfriend-suite/var/log" \
    "/opt/smartfriend-suite/apps" \
    "/opt/smartfriend-suite/apps/core" \
    "/opt/smartfriend-suite/apps/brain" \
    "/opt/smartfriend-suite/apps/harvester" \
    "/opt/smartfriend-suite/apps/unified" \
    "/opt/smartfriend-suite/apps/web" \
    "/opt/smartfriend-suite/apps/telegram" \
    "/opt/smartfriend-suite/apps/learning" \
    "/opt/smartfriend-suite/apps/memory" \
    "/opt/smartfriend-suite/apps/ffactory" \
    "/opt/smartfrind" \
    "/opt/ffactory"
  do
    [ -d "$d" ] && ls -ld "$d" || echo "MISSING: $d"
  done
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 2) Database / knowledge files under SmartFriend Suite"
  echo
  find "$BASE_DIR" -maxdepth 5 -type f \( \
      -name 'smartfriend_unified.db' -o \
      -name '*memory*.db' -o \
      -name '*knowledge*.db' \
    \) -print0 2>/dev/null | xargs -0 -r ls -l
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 3) systemd units – smartfriend-* (Suite Core APIs)"
  echo
  systemctl list-unit-files 'smartfriend-*' 2>/dev/null || true
  echo
  systemctl list-units 'smartfriend-*' --no-pager --plain 2>/dev/null || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 4) systemd units – sf-* (Suite helpers / health / dev)"
  echo
  systemctl list-unit-files 'sf-*' 2>/dev/null || true
  echo
  systemctl list-units 'sf-*' --no-pager --plain 2>/dev/null || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 5) systemd units – smartfrind-* (Legacy engines)"
  echo
  systemctl list-unit-files 'smartfrind-*' 2>/dev/null || true
  echo
  systemctl list-units 'smartfrind-*' --no-pager --plain 2>/dev/null || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 6) Detailed ExecStart for all related units"
  echo
  for prefix in smartfriend- sf- smartfrind-; do
    echo "----- $prefix* units -----"
    systemctl list-unit-files "${prefix}*" --no-legend 2>/dev/null | awk '{print $1}' | while read -r unit; do
      [ -z "$unit" ] && continue
      echo
      echo "[$unit]"
      systemctl show "$unit" -p Id -p Description -p FragmentPath -p ExecStart 2>/dev/null || true
    done
    echo
  done
  echo "------------------------------------------------------------"
  echo

  echo "### 7) Listening ports for SmartFriend / SmartFrind / FFactory"
  echo
  command -v ss >/dev/null 2>&1 || { echo "ss command not found – skipping ports section"; echo; }
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>/dev/null | grep -E '(:80|:8000|:8220|:821[0-9]|:82[0-9]{2})' || echo "No matching ports found."
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 8) Nginx gateway configs (if present)"
  echo
  for f in \
    "/etc/nginx/nginx.conf" \
    "/etc/nginx/sites-enabled/default" \
    "/etc/nginx/sites-enabled/smartfriend.conf" \
    "/opt/ffactory/stack/nginx.gateway.conf"
  do
    if [ -f "$f" ]; then
      echo ">>> $f"
      sed -n '1,220p' "$f"
      echo
    else
      echo "MISSING: $f"
    fi
    echo
  done
  echo "------------------------------------------------------------"
  echo

  echo "End of SmartFriend Suite Service Inventory Report"
  echo "============================================================"
} | tee "$REPORT_FILE"

log "تم إنشاء تقرير الجرد:"
log "  $REPORT_FILE"
