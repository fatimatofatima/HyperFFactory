#!/usr/bin/env bash
# HyperFFactory – Diagnose SmartFriend Suite + Telegram bot units

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$REPORT_DIR/hf_diag_smartfriend_services_${TS}.txt"

{
  echo "====================================================="
  echo "HyperFFactory – SmartFriend Suite & Telegram Bot Diagnostics"
  echo "ROOT : $ROOT"
  echo "TIME : $TS"
  echo "OUT  : $OUT"
  echo "====================================================="
  echo

  echo "== 1) Systemd status snapshot =="
  echo
  systemctl --no-pager -l status sf-core sf-web sf-health sf-memory sf-bot || true
  echo
  echo "-----------------------------------------------------"
  echo

  echo "== 2) Unit files – ExecStart / WorkingDirectory =="
  echo

  for unit in sf-core sf-web sf-health sf-memory sf-bot; do
    svc="/etc/systemd/system/${unit}.service"
    echo "--- ${svc} ---"
    if [ -f "$svc" ]; then
      grep -E '^(WorkingDirectory|ExecStart)=' "$svc" || echo "  (no ExecStart/WorkingDirectory found)"
    else
      echo "  (unit file not found)"
    fi
    echo
  done

  echo "-----------------------------------------------------"
  echo

  echo "== 3) Last 40 log lines per service (journalctl) =="
  echo

  for unit in sf-core sf-web sf-health sf-memory sf-bot; do
    echo "--- journalctl -u ${unit}.service (last 40 lines) ---"
    journalctl -u "${unit}.service" -n 40 --no-pager || echo "  (no logs)"
    echo
  done

  echo "====================================================="
  echo "DONE – diagnostics written to: $OUT"
  echo "====================================================="

} | tee "$OUT"
