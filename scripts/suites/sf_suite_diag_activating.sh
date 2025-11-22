#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

OUT="/root/sf_reports/sf_suite_diag_activating_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /root/sf_reports

echo "=== تشخيص الخدمات في حالة activating/failed (sf-*, smartfriend-*, smartfrind-*) ===" | tee "$OUT"
echo "[وقت التقرير: $(date '+%F %T')]" | tee -a "$OUT"
echo | tee -a "$OUT"

mapfile -t PROBLEM_UNITS < <(
  systemctl list-units 'sf-*.service' 'smartfriend-*.service' 'smartfrind-*.service' \
    --state=activating,failed --no-legend 2>/dev/null | awk '{print $1}' | sort -u
)

if ((${#PROBLEM_UNITS[@]} == 0)); then
  echo "لا توجد خدمات sf-*/smartfriend-*/smartfrind-* في حالة activating/failed حالياً." | tee -a "$OUT"
  exit 0
fi

echo "الخدمات التي تحتاج تشخيص:" | tee -a "$OUT"
for u in "${PROBLEM_UNITS[@]}"; do
  echo "  - $u" | tee -a "$OUT"
done
echo | tee -a "$OUT"

for u in "${PROBLEM_UNITS[@]}"; do
  echo "============================================================" | tee -a "$OUT"
  echo "### الخدمة: $u" | tee -a "$OUT"
  echo "------------------------------------------------------------" | tee -a "$OUT"
  echo ">> systemctl status $u --no-pager" | tee -a "$OUT"
  systemctl status "$u" --no-pager 2>&1 | tee -a "$OUT"

  echo "------------------------------------------------------------" | tee -a "$OUT"
  echo ">> systemctl cat $u | grep -E 'ExecStart|Description' -n" | tee -a "$OUT"
  systemctl cat "$u" 2>/dev/null | grep -nE '^\s*ExecStart|^\s*Description' || echo "(لا يوجد cat/ExecStart واضح)" | tee -a "$OUT"

  echo "------------------------------------------------------------" | tee -a "$OUT"
  echo ">> journalctl -u $u -n 80 --no-pager" | tee -a "$OUT"
  journalctl -u "$u" -n 80 --no-pager 2>&1 | tee -a "$OUT"
  echo | tee -a "$OUT"
done

echo "=== انتهى التشخيص. الملف: $OUT ===" | tee -a "$OUT"
