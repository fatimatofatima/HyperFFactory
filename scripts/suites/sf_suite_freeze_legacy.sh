#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

REPORT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_suite_freeze_legacy_${TS}.log"

DRY_RUN="${DRY_RUN:-1}"

log(){ echo "[$(date '+%F %T')] $*"; }

stop_disable_unit() {
  local unit="$1"
  [[ -z "$unit" ]] && return 0

  local state active
  state="$(systemctl list-unit-files "$unit" --no-legend 2>/dev/null | awk '{print $2}' || echo "unknown")"
  active="$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")"

  log "Unit: $unit (state=$state, active=$active)" | tee -a "$REPORT"

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$active" == "active" || "$active" == "activating" ]]; then
      log "DRY-RUN: would systemctl stop $unit" | tee -a "$REPORT"
    fi
    if [[ "$state" == "enabled" ]]; then
      log "DRY-RUN: would systemctl disable $unit" | tee -a "$REPORT"
    fi
  else
    if [[ "$active" == "active" || "$active" == "activating" ]]; then
      log "systemctl stop $unit" | tee -a "$REPORT"
      systemctl stop "$unit" 2>&1 | tee -a "$REPORT" || true
    fi
    if [[ "$state" == "enabled" ]]; then
      log "systemctl disable $unit" | tee -a "$REPORT"
      systemctl disable "$unit" 2>&1 | tee -a "$REPORT" || true
    fi
  fi
}

main() {
  {
    echo "============================================================"
    echo " SmartFriend Suite – Freeze smartfrind-* Legacy Units"
    echo " Timestamp : $(date '+%F %T')"
    echo " Hostname  : $(hostname)"
    echo " DRY_RUN   : $DRY_RUN (1=log فقط، 0=إيقاف+disable فعلي)"
    echo "============================================================"
    echo
  } | tee "$REPORT"

  # اكتشاف وحدات smartfrind-* المسجلة في النظام
  echo "1) Listing smartfrind-* unit-files" | tee -a "$REPORT"
  systemctl list-unit-files "smartfrind-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "2) تجميد الوحدات الأساسية (services / timers / sockets / paths)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  LEGACY_UNITS=(
    smartfrind-ask.service
    smartfrind-guardian.service
    smartfrind-gateway.socket
    smartfrind-bot.path
    smartfrind-core-watchdog.timer
    smartfrind-harvest.timer
    smartfrind-ingest.timer
    smartfrind-envwatch.service
    smartfrind-gateway.service
    smartfrind-harvest.service
    smartfrind-ingest.service
    smartfrind-setup.sh.service
    smartfrind-delta.sh.service
  )

  for u in "${LEGACY_UNITS[@]}"; do
    stop_disable_unit "$u"
  done

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "3) Snapshot سريع بعد التجميد" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  log "systemctl list-units 'smartfrind-*' (runtime):" | tee -a "$REPORT"
  systemctl list-units "smartfrind-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  log "systemctl list-unit-files 'smartfrind-*' (unit files):" | tee -a "$REPORT"
  systemctl list-unit-files "smartfrind-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  log "Freeze finished. Report: $REPORT" | tee -a "$REPORT"
}

main
