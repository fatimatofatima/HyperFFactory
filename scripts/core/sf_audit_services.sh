#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
banner(){ echo; echo "========== $* =========="; }

log "بدء فحص الخدمات على السيرفر"

banner "1) ملخص عام للخدمات العاملة (running)"
systemctl list-units --type=service --state=running --no-pager

banner "2) الخدمات الفاشلة (failed)"
systemctl list-units --type=service --state=failed --no-pager || true

banner "3) الخدمات المفعّلة على الإقلاع (enabled)"
systemctl list-unit-files --type=service | grep enabled || true

banner "4) خدمات SmartFriend / SmartFrind / ffactory بالتفصيل"
project_services="$(systemctl list-unit-files --type=service --no-legend 2>/dev/null \
  | awk '{print $1}' \
  | grep -E '^(sf-|smartfrind-|smartfriend-|ffactory)' \
  || true)"

if [[ -z "$project_services" ]]; then
  echo "لا توجد خدمات مطابقة للنمط (sf-|smartfrind-|smartfriend-|ffactory)."
else
  for svc in $project_services; do
    echo
    echo "----- الخدمة: $svc -----"
    # حالة الخدمة
    systemctl status "$svc" --no-pager -n 10 || true

    echo
    echo "[تفاصيل الوحدة ومواقع الملفات]"
    systemctl show "$svc" \
      -p FragmentPath \
      -p Description \
      -p ActiveState \
      -p SubState \
      -p ExecStart \
      -p WorkingDirectory \
      -p EnvironmentFile \
      --no-pager || true
  done
fi

banner "5) Timers مرتبطة بـ smartfrind / smartfriend / sf-"
systemctl list-unit-files --type=timer --no-legend 2>/dev/null \
  | grep -E 'smartfrind|smartfriend|sf-' \
  || echo "لا يوجد timers خاصة بالمشروع."

banner "انتهاء فحص الخدمات"
log "انتهاء فحص الخدمات"
