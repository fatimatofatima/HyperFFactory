#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

print_sep(){
  printf '\n%s\n' "======================================================================"
}

print_unit(){
  local svc="$1"
  local label="$2"

  print_sep
  log "خدمة: $label ($svc)"
  echo

  if ! systemctl status "$svc" &>/dev/null; then
    echo "  ⚠ الخدمة غير موجودة أو لا يمكن قراءتها: $svc"
    return 0
  fi

  echo "  --- STATUS: systemctl status $svc ---"
  systemctl status "$svc" --no-pager -l | sed 's/^/  /'

  echo
  echo "  --- LOG: آخر 30 سطر من journalctl -u $svc ---"
  if ! journalctl -u "$svc" -n 30 --no-pager -o short-iso 2>/dev/null | sed 's/^/  /'; then
    echo "  (لا توجد سجلات متاحة أو لا يمكن قراءة اللوجات)"
  fi
}

log "لقطة حالة SmartFriend Suite"
echo "Hostname: $(hostname)"
echo "وقت السيرفر: $(date '+%F %T %Z')"
print_sep

echo "1) الخدمات المفترض أنها مستقرة:"
print_unit "smartfrind-gateway.service" "Gateway"
print_unit "smartfrind-api.service" "Core API"
print_unit "sf-bot-programmer.service" "Programmer Bot"

echo
echo "2) الخدمات التي كان فيها مشاكل وتم لمسها:"
print_unit "sf-spider.service" "Spider (Web Harvester)"
print_unit "sf-bot-behavior.service" "Behavior Bot"

print_sep
log "انتهت لقطة الحالة."
