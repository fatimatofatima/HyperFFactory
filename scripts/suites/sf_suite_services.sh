#!/usr/bin/env bash
set -Eeuo pipefail

UNITS=(
  smartfriend-api.service
  smartfrind-gateway.service
  deepseek-api.service
  ff-board.service
  ff-healthd.service
)

OUT="/root/sf_suite_services_$(date +%Y%m%d_%H%M%S).log"

log_sec() {
  echo
  echo "============================================================" | tee -a "$OUT"
  echo ">>> $1" | tee -a "$OUT"
  echo "============================================================" | tee -a "$OUT"
}

log_sec "SmartFriend Suite – Services Inventory"

for u in "${UNITS[@]}"; do
  echo | tee -a "$OUT"
  echo "##### $u #####" | tee -a "$OUT"
  if systemctl list-unit-files "$u" >/dev/null 2>&1; then
    echo "-- systemctl status (short) --" | tee -a "$OUT"
    systemctl status "$u" --no-pager --lines=3 2>&1 | tee -a "$OUT" || true

    echo | tee -a "$OUT"
    echo "-- systemctl cat --" | tee -a "$OUT"
    systemctl cat "$u" 2>&1 | tee -a "$OUT" || true
  else
    echo "Unit not found" | tee -a "$OUT"
  fi
done

echo | tee -a "$OUT"
echo "===================== END OF SERVICES REPORT =================" | tee -a "$OUT"

echo
echo "Report saved to: $OUT"
