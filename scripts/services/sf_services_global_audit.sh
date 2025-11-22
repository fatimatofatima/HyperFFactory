#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){
  echo
  echo "================================================================"
  echo "== $*"
  echo "================================================================"
}

section "Node / Resources"
hostnamectl | sed -n '1,3p' || true
echo
uptime || true
echo
df -h / | sed -n '1,2p' || true
echo
free -h || true

section "Core Infra (DB / Docker / Web / Security)"
check_unit(){
  local name="$1"
  # نتحقق أولًا هل الخدمة معرفة قبل عرض حالتها
  if systemctl list-unit-files "${name}.service" &>/dev/null; then
    echo
    log "Status: ${name}.service"
    systemctl status "${name}.service" --no-pager -n 3 || true
  fi
}

check_unit "postgresql@16-main"
check_unit "docker"
check_unit "nginx"
check_unit "ollama"
check_unit "deepseek-api"
check_unit "searxng-compose"
check_unit "auditd"
check_unit "fail2ban"

section "SmartFriend Suite (sf-*.service)"
systemctl list-units "sf-*.service" --no-pager --no-legend 2>/dev/null \
  | awk '{printf "  %-35s %-10s %-10s %s\n",$1,$2,$3,substr($0,index($0,$4))}' || true

section "SmartFrind Stack (smartfrind-*.service)"
systemctl list-units "smartfrind-*.service" --no-pager --no-legend 2>/dev/null \
  | awk '{printf "  %-35s %-10s %-10s %s\n",$1,$2,$3,substr($0,index($0,$4))}' || true

section "SmartFriend Official (smartfriend-*.service)"
systemctl list-units "smartfriend-*.service" --no-pager --no-legend 2>/dev/null \
  | awk '{printf "  %-35s %-10s %-10s %s\n",$1,$2,$3,substr($0,index($0,$4))}' || true

section "ffactory / factory stack"
systemctl list-units "ff-*.service" "ffactory*.service" "factory-gw.service" \
  --no-pager --no-legend 2>/dev/null \
  | awk '{printf "  %-35s %-10s %-10s %s\n",$1,$2,$3,substr($0,index($0,$4))}' || true

section "System-wide FAILED services"
FAILED_UNITS=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | awk '{print $1}')

if [ -z "$FAILED_UNITS" ]; then
  log "لا توجد خدمات في حالة FAILED حالياً."
else
  systemctl list-units --type=service --state=failed --no-pager || true

  for u in $FAILED_UNITS; do
    echo
    log "تفاصيل الخدمة الفاشلة: $u"
    systemctl status "$u" --no-pager -n 5 || true
  done
fi

echo
log "انتهى فحص الخدمات (Global Services Audit)."
