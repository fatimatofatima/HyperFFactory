#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
OUT="/root/sf_reports/sf_suite_deep_diag_${TS}.log"
mkdir -p /root/sf_reports

log(){ echo "$@" | tee -a "$OUT"; }

log "=== SmartFriend Suite – Deep Diag for activating/failed units ==="
log "[وقت التقرير: $(date '+%F %T')]"
log

# نجمع كل الوحدات sf-*/smartfriend-*/smartfrind-* في حالة activating أو failed
mapfile -t UNITS < <(
  systemctl list-units 'sf-*.service' 'smartfriend-*.service' 'smartfrind-*.service' \
    --state=activating,failed --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u
)

if ((${#UNITS[@]} == 0)); then
  log "لا توجد خدمات sf-*/smartfriend-*/smartfrind-* في حالة activating/failed حالياً."
  exit 0
fi

log "الخدمات التي تحتاج تشخيص:"
for u in "${UNITS[@]}"; do
  log "  - $u"
done
log
log "============================================================"

for u in "${UNITS[@]}"; do
  log "### الخدمة: $u"
  log "------------------------------------------------------------"

  # 1) systemctl status
  log ">> systemctl status $u --no-pager -n 20"
  systemctl status "$u" --no-pager -n 20 2>&1 | tee -a "$OUT"
  log

  # 2) موقع ملف الـ unit + الأسطر المهمة (ExecStart/WorkingDirectory/User/Group)
  UNIT_FILE="$(systemctl show -p FragmentPath "$u" 2>/dev/null | sed 's/FragmentPath=//')"
  if [[ -n "$UNIT_FILE" && -f "$UNIT_FILE" ]]; then
    log ">> ملف الوحدة: $UNIT_FILE"
    log ">> الأسطر المهمة من ملف الوحدة:"
    grep -E '^(ExecStart|WorkingDirectory|User=|Group=|Environment=)' "$UNIT_FILE" 2>/dev/null | tee -a "$OUT" || true
  else
    log ">> ملف الوحدة غير معروف أو غير موجود (FragmentPath فارغ)."
  fi
  log

  # 3) آخر 40 سطر من اللوج
  log ">> journalctl -u $u -n 40 --no-pager"
  journalctl -u "$u" -n 40 --no-pager 2>&1 | tee -a "$OUT"
  log
  log "============================================================"
done

log "تم حفظ التقرير في: $OUT"
